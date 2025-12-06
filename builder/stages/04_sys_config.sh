#!/bin/bash
# STAGE 04: System Configuration (Hardening & RO Prep)

log_step "04_sys_config.sh - Configuring OS Environment"

# 1. Подготовка
log_info "Mounting system binds..."
cp /usr/bin/qemu-aarch64-static /mnt/dst/usr/bin/
mount_bind /dev /mnt/dst/dev
mount_bind /dev/pts /mnt/dst/dev/pts
mount_bind /sys /mnt/dst/sys
mount_bind /proc /mnt/dst/proc

# 2. Инъекция конфигов
log_info "Injecting system configurations..."

# Udev Rules (Network + Hiding Partitions)
cp -v "$WORKSPACE_DIR/system/udev/70-persistent-net.rules" /mnt/dst/etc/udev/rules.d/
cp -v "$WORKSPACE_DIR/system/udev/99-hide-partitions.rules" /mnt/dst/etc/udev/rules.d/

# Services & Boot configs
cp -v "$WORKSPACE_DIR/system/systemd/rfkill-unblock.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/boot/keyboard" /mnt/dst/etc/default/keyboard
cp -v "$WORKSPACE_DIR/system/boot/console-setup" /mnt/dst/etc/default/console-setup

# 3. Подготовка структуры данных (/data)
# Создаем папки, которые будут на RW разделе
mkdir -p /mnt/dst/data/system
mkdir -p /mnt/dst/data/app
mkdir -p /mnt/dst/data/docker
mkdir -p /mnt/dst/data/logs_archive

# 4. CHROOT
export SYS_ENABLE_SSH SYS_USER SYS_PASS NET_HOSTNAME NET_WIFI_SSID NET_WIFI_PASS NET_WIFI_COUNTRY
export BUILD_VERSION BUILD_MODE

cat <<EOF | chroot /mnt/dst /bin/bash
set -e

# --- A. УДАЛЕНИЕ ЛИШНЕГО ---
echo "Purging unnecessary services..."
apt-get remove -y --purge userconf-pi cloud-init dphys-swapfile logrotate triggerhappy || true
apt-get autoremove -y
rm -rf /usr/lib/userconf-pi /etc/cloud /var/lib/cloud /var/swap

# Отключаем apt-daily таймеры (они вызывают нагрузку на диск и ошибки в RO)
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable man-db.timer

# --- Б. RO FIXES (Симлинки и хаки) ---
echo "Applying Read-Only Fixes..."

# 1. DNS (Resolv.conf)
# NetworkManager пишет сюда. Переносим в tmpfs (/run)
rm -f /etc/resolv.conf
ln -s /run/NetworkManager/resolv.conf /etc/resolv.conf

# 2. Random Seed (Энтропия)
# systemd-random-seed пытается писать в /var/lib/systemd/random-seed при выключении
# Переносим это на /data, чтобы энтропия сохранялась
rm -f /var/lib/systemd/random-seed
# Ссылка будет работать, когда /data смонтируется
ln -s /data/system/random-seed /var/lib/systemd/random-seed

# 3. База данных NetworkManager (Leases, timestamps)
# По умолчанию в /var/lib/NetworkManager. Переносим в tmpfs или /data.
# Лучше в tmpfs (забываем сети при ребуте) или /data (помним).
# Выберем /data для стабильности.
rm -rf /var/lib/NetworkManager
ln -s /data/system/nm-state /var/lib/NetworkManager
mkdir -p /data/system/nm-state

# 4. SSH Host Keys
# Ключи хоста должны быть постоянными! Иначе при каждой загрузке будет "Man in the middle attack" warning.
# Перемещаем ключи генерации на /data
# (Скрипт генерации ключей ssh нужно будет подправить или оставить как есть, если он увидит ключи)
# Пока оставим в /etc/ssh (RO). Они сгенерируются один раз при ПЕРВОЙ загрузке?
# НЕТ! При первой загрузке корень уже RO. Ключи не создадутся.
# РЕШЕНИЕ: Генерируем ключи ПРЯМО СЕЙЧАС при сборке.
echo "Pre-generating SSH Host Keys..."
ssh-keygen -A

# --- В. СТАНДАРТНАЯ НАСТРОЙКА (Локаль, Сеть, Юзеры) ---
# (Этот блок остается таким же, как был, только без создания файлов в /etc/...)

echo "Generating Locales..."
apt-get install -y locales console-setup console-setup-linux
cat > /etc/locale.gen <<LOCALEEOF
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
LOCALEEOF
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

echo "Setting hostname: $NET_HOSTNAME"
echo "$NET_HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "127.0.1.1 $NET_HOSTNAME" >> /etc/hosts

if [ "$SYS_ENABLE_SSH" == "yes" ]; then
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
fi

echo "Configuring Network..."
systemctl enable NetworkManager
systemctl disable wpa_supplicant
systemctl stop wpa_supplicant || true
rm -f /var/lib/NetworkManager/NetworkManager.state

systemctl enable rfkill-unblock.service
systemctl unmask systemd-rfkill.service || true

if [ -n "$NET_WIFI_COUNTRY" ]; then
    mkdir -p /etc/wpa_supplicant
    echo "country=$NET_WIFI_COUNTRY" > /etc/wpa_supplicant/wpa_supplicant.conf
fi

if [ -n "$NET_WIFI_SSID" ]; then
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

# --- Г. ВЕРСИОНИРОВАНИЕ ---
cat > /etc/headunit-release <<VEREOF
NAME="HeadUnit OS"
ID=headunit
VERSION_ID="$BUILD_VERSION"
PRETTY_NAME="HeadUnit OS $BUILD_VERSION ($BUILD_MODE)"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
VEREOF

mkdir -p /opt/headunit
cat > /opt/headunit/version.json <<JSONEOF
{
  "os_version": "$BUILD_VERSION",
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "build_mode": "$BUILD_MODE"
}
JSONEOF

echo "Welcome to HeadUnit OS $BUILD_VERSION" > /etc/motd

EOF

# 4. Уборка
rm -f /mnt/dst/usr/bin/qemu-aarch64-static
umount_safe /mnt/dst/proc
umount_safe /mnt/dst/sys
umount_safe /mnt/dst/dev/pts
umount_safe /mnt/dst/dev

log_info "OS Hardening Complete."
