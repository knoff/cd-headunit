#!/bin/bash
# STAGE 04: System Configuration (User, Network, Locales, Services)

log_step "04_sys_config.sh - Configuring OS Environment"

# 1. Подготовка (Монтирование биндов)
log_info "Mounting system binds for chroot..."
cp /usr/bin/qemu-aarch64-static /mnt/dst/usr/bin/
mount_bind /dev /mnt/dst/dev
mount_bind /dev/pts /mnt/dst/dev/pts
mount_bind /sys /mnt/dst/sys
mount_bind /proc /mnt/dst/proc

# 2. Копирование системных конфигов (Injection)
# Берем файлы из папки system/ репозитория
log_info "Injecting system configurations..."

# Udev Rules (Network Naming wlan0/wlan1)
cp -v "$WORKSPACE_DIR/system/udev/70-persistent-net.rules" /mnt/dst/etc/udev/rules.d/

# Systemd Services (RFKill Unblocker)
cp -v "$WORKSPACE_DIR/system/systemd/rfkill-unblock.service" /mnt/dst/etc/systemd/system/

# Console & Keyboard Defaults
cp -v "$WORKSPACE_DIR/system/boot/keyboard" /mnt/dst/etc/default/keyboard
cp -v "$WORKSPACE_DIR/system/boot/console-setup" /mnt/dst/etc/default/console-setup

# 3. Вход в систему (Chroot)
export SYS_ENABLE_SSH SYS_USER SYS_PASS NET_HOSTNAME NET_WIFI_SSID NET_WIFI_PASS NET_WIFI_COUNTRY
export BUILD_VERSION BUILD_MODE

cat <<EOF | chroot /mnt/dst /bin/bash
set -e

# --- А. ОЧИСТКА ---
echo "Purging First-Run Wizards..."
apt-get remove -y --purge userconf-pi cloud-init || true
rm -f /usr/lib/systemd/system/userconf-pi.service
rm -rf /usr/lib/userconf-pi /etc/cloud /var/lib/cloud
rm -f /boot/firmware/userconf.txt /boot/userconf.txt
rm -f /etc/init.d/apply_noobs_os_config

systemctl enable getty@tty1.service

# --- Б. ЛОКАЛИЗАЦИЯ ---
echo "Generating Locales..."
apt-get install -y locales console-setup console-setup-linux

# Генерируем локали
cat > /etc/locale.gen <<LOCALEEOF
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
LOCALEEOF
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# --- В. ПОЛЬЗОВАТЕЛИ ---
echo "Setting hostname: $NET_HOSTNAME"
echo "$NET_HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "127.0.1.1 $NET_HOSTNAME" >> /etc/hosts

if [ "$SYS_ENABLE_SSH" == "yes" ]; then
    echo "Enabling SSH..."
    systemctl enable ssh
    if ! id "$SYS_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$SYS_USER"
        usermod -aG sudo,video,render,input,netdev,plugdev "$SYS_USER"
    fi
    echo "$SYS_USER:$SYS_PASS" | chpasswd
    echo "root:$SYS_PASS" | chpasswd

    # Удаляем pi
    if [ "$SYS_USER" != "pi" ] && id "pi" &>/dev/null; then
        pkill -u pi || true
        deluser --remove-home pi || true
    fi
else
    systemctl disable ssh
fi

# --- Г. СЕТЬ И СЕРВИСЫ ---
echo "Configuring Network..."
systemctl enable NetworkManager

# Отключаем конфликтный wpa_supplicant (системный)
systemctl disable wpa_supplicant
systemctl stop wpa_supplicant || true
rm -f /var/lib/NetworkManager/NetworkManager.state

# Включаем наш RFKill сервис (файл скопирован выше)
systemctl enable rfkill-unblock.service
systemctl unmask systemd-rfkill.service || true

# Wi-Fi Country (для драйвера)
if [ -n "$NET_WIFI_COUNTRY" ]; then
    mkdir -p /etc/wpa_supplicant
    echo "country=$NET_WIFI_COUNTRY" > /etc/wpa_supplicant/wpa_supplicant.conf
    echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev" >> /etc/wpa_supplicant/wpa_supplicant.conf
    echo "update_config=1" >> /etc/wpa_supplicant/wpa_supplicant.conf

    if [ -f /etc/default/crda ]; then
        sed -i "s/^REGDOMAIN=.*/REGDOMAIN=$NET_WIFI_COUNTRY/" /etc/default/crda
    fi
fi

# Wi-Fi Connection Profile (Client -> wlan1)
# Этот файл мы генерируем тут, так как в нем секреты из ENV
if [ -n "$NET_WIFI_SSID" ]; then
    echo "Configuring Wi-Fi Client on wlan1..."
    mkdir -p /etc/NetworkManager/system-connections
    chmod 700 /etc/NetworkManager/system-connections

    UUID_WIFI=\$(cat /proc/sys/kernel/random/uuid)

    cat > "/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection" <<NMEOF
[connection]
id=preconfigured-wifi
uuid=\$UUID_WIFI
type=wifi
interface-name=wlan1
autoconnect=true
autoconnect-priority=100

[wifi]
mode=infrastructure
ssid=$NET_WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$NET_WIFI_PASS

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto
NMEOF
    chmod 600 "/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection"
    chown root:root "/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection"
fi

# --- Д. ВЕРСИОНИРОВАНИЕ ---
echo "Stamping System Version: $BUILD_VERSION"

# 1. Основной файл релиза (стандарт Systemd)
cat > /etc/headunit-release <<VEREOF
NAME="HeadUnit OS"
ID=headunit
VERSION_ID="$BUILD_VERSION"
PRETTY_NAME="HeadUnit OS $BUILD_VERSION ($BUILD_MODE)"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
HOME_URL="https://github.com/cdreborn/headunit"
VEREOF

# 2. Файл-флаг для приложений (JSON)
mkdir -p /opt/headunit
cat > /opt/headunit/version.json <<JSONEOF
{
  "os_version": "$BUILD_VERSION",
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "build_mode": "$BUILD_MODE"
}
JSONEOF

# 3. MOTD
echo "Welcome to HeadUnit OS $BUILD_VERSION" > /etc/motd

EOF

# 4. Уборка
log_info "Unmounting chroot binds..."
rm -f /mnt/dst/usr/bin/qemu-aarch64-static
umount_safe /mnt/dst/proc
umount_safe /mnt/dst/sys
umount_safe /mnt/dst/dev/pts
umount_safe /mnt/dst/dev

log_info "OS Configuration Complete."
