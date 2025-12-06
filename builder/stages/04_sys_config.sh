#!/bin/bash
# STAGE 04: System Configuration (User, SSH, Network, Locales)

log_step "04_sys_config.sh - Configuring OS Environment"

# 1. Подготовка Chroot
log_info "Mounting system binds for chroot..."

cp /usr/bin/qemu-aarch64-static /mnt/dst/usr/bin/

mount_bind /dev /mnt/dst/dev
mount_bind /dev/pts /mnt/dst/dev/pts
mount_bind /sys /mnt/dst/sys
mount_bind /proc /mnt/dst/proc

export SYS_ENABLE_SSH SYS_USER SYS_PASS NET_HOSTNAME NET_WIFI_SSID NET_WIFI_PASS NET_WIFI_COUNTRY

# ================= START CHROOT =================
cat <<EOF | chroot /mnt/dst /bin/bash
set -e

# --- 0. ОЧИСТКА МУСОРА ---
echo "Purging First-Run Wizards..."
apt-get remove -y --purge userconf-pi cloud-init || true
rm -f /usr/lib/systemd/system/userconf-pi.service
rm -f /etc/systemd/system/sysinit.target.wants/userconf-pi.service
rm -rf /usr/lib/userconf-pi
rm -rf /etc/cloud /var/lib/cloud
rm -f /boot/firmware/userconf.txt /boot/userconf.txt
rm -f /etc/init.d/apply_noobs_os_config

systemctl enable getty@tty1.service

# --- 1. ЛОКАЛИЗАЦИЯ (Dual Locale) ---
echo "Generating Locales (en_US & ru_RU)..."

# Убеждаемся, что пакет установлен
apt-get install -y locales

# Прописываем две нужные локали. Все остальные будут удалены (не сгенерированы).
cat > /etc/locale.gen <<LOCALEEOF
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
LOCALEEOF

# Генерируем
locale-gen

# Дефолт - английский (для логов), русский доступен
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# --- 2. КЛАВИАТУРА (US + RU, Ctrl+Shift) ---
echo "Configuring Keyboard (US, RU)..."
cat > /etc/default/keyboard <<KEYEOF
XKBMODEL="pc105"
XKBLAYOUT="us,ru"
XKBVARIANT=","
XKBOPTIONS="grp:ctrl_shift_toggle"
BACKSPACE="guess"
KEYEOF

# --- A. Hostname ---
echo "Setting hostname: $NET_HOSTNAME"
echo "$NET_HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "127.0.1.1 $NET_HOSTNAME" >> /etc/hosts

# --- B. Пользователь и SSH ---
if [ "$SYS_ENABLE_SSH" == "yes" ]; then
    echo "Enabling SSH..."
    systemctl enable ssh
    if ! id "$SYS_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$SYS_USER"
        usermod -aG sudo,video,render,input,netdev,plugdev "$SYS_USER"
    fi
    echo "$SYS_USER:$SYS_PASS" | chpasswd
    echo "root:$SYS_PASS" | chpasswd

    if [ "$SYS_USER" != "pi" ] && id "pi" &>/dev/null; then
        pkill -u pi || true
        deluser --remove-home pi || true
    fi
else
    systemctl disable ssh
fi

# --- C. Настройка Сети ---
echo "Configuring Network..."
systemctl enable NetworkManager

# Wi-Fi Country
if [ -n "$NET_WIFI_COUNTRY" ]; then
    echo "Setting WiFi Country to $NET_WIFI_COUNTRY..."
    mkdir -p /etc/wpa_supplicant
    echo "country=$NET_WIFI_COUNTRY" > /etc/wpa_supplicant/wpa_supplicant.conf
    echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev" >> /etc/wpa_supplicant/wpa_supplicant.conf
    echo "update_config=1" >> /etc/wpa_supplicant/wpa_supplicant.conf

    if [ -f /etc/default/crda ]; then
        sed -i "s/^REGDOMAIN=.*/REGDOMAIN=$NET_WIFI_COUNTRY/" /etc/default/crda
    fi
fi

# Wi-Fi Connection
if [ -n "$NET_WIFI_SSID" ]; then
    echo "Configuring Wi-Fi Client: $NET_WIFI_SSID"
    mkdir -p /etc/NetworkManager/system-connections
    chmod 700 /etc/NetworkManager/system-connections

    UUID_WIFI=\$(cat /proc/sys/kernel/random/uuid)

    cat > "/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection" <<NMEOF
[connection]
id=preconfigured-wifi
uuid=\$UUID_WIFI
type=wifi
interface-name=wlan0
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

# RF Unblock
systemctl unmask systemd-rfkill.service || true
systemctl unmask systemd-rfkill.socket || true

EOF
# ================= END CHROOT =================

# 3. Уборка
log_info "Unmounting chroot binds..."
rm -f /mnt/dst/usr/bin/qemu-aarch64-static
umount_safe /mnt/dst/proc
umount_safe /mnt/dst/sys
umount_safe /mnt/dst/dev/pts
umount_safe /mnt/dst/dev

log_info "OS Configuration Complete."
