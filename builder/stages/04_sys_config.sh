#!/bin/bash
# STAGE 04: System Configuration (Custom Initramfs Hook + Python Fix)

log_step "04_sys_config.sh - Configuring OS Environment"

# 1. Подготовка
log_info "Mounting system binds..."
cp /usr/bin/qemu-aarch64-static /mnt/dst/usr/bin/
mount_bind /dev /mnt/dst/dev
mount_bind /dev/pts /mnt/dst/dev/pts
mount_bind /sys /mnt/dst/sys
mount_bind /proc /mnt/dst/proc

# 2. Инъекция
cp -v "$WORKSPACE_DIR/system/udev/70-persistent-net.rules" /mnt/dst/etc/udev/rules.d/
cp -v "$WORKSPACE_DIR/system/udev/99-hide-partitions.rules" /mnt/dst/etc/udev/rules.d/
cp -v "$WORKSPACE_DIR/system/systemd/rfkill-unblock.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/boot/keyboard" /mnt/dst/etc/default/keyboard
cp -v "$WORKSPACE_DIR/system/boot/console-setup" /mnt/dst/etc/default/console-setup

# Подготовка скрипта оверлея
mkdir -p /mnt/dst/tmp/overlay_script
cp -v "$WORKSPACE_DIR/system/scripts/overlay-init" /mnt/dst/tmp/overlay_script/overlay

# 3. Data папки
mkdir -p /mnt/dst/data/app
mkdir -p /mnt/dst/data/configs
mkdir -p /mnt/dst/data/db

# 4. CHROOT
export SYS_ENABLE_SSH SYS_USER SYS_PASS NET_HOSTNAME NET_WIFI_SSID NET_WIFI_PASS NET_WIFI_COUNTRY
export BUILD_VERSION BUILD_MODE

cat <<EOF | chroot /mnt/dst /bin/bash
set -e

# --- A. ОЧИСТКА ---
# Удаляем только конкретные пакеты, НЕ трогаем зависимости (Python)
apt-get remove -y userconf-pi cloud-init dphys-swapfile || true
rm -rf /usr/lib/userconf-pi /etc/cloud /var/lib/cloud /var/swap

systemctl disable apt-daily.timer apt-daily-upgrade.timer man-db.timer
systemctl mask rpi-resize.service systemd-growfs-root.service rpi-resize-swap-file.service

# --- Б. INITRAMFS СБОРКА ---
echo "Building Custom Initramfs..."
apt-get update
# Добавляем шрифты, чтобы setupcon не ругался
apt-get install -y initramfs-tools locales console-setup kbd busybox-static console-data

# 1. Модуль
echo "overlay" >> /etc/initramfs-tools/modules

# 2. Установка скрипта в init-bottom
chmod +x /tmp/overlay_script/overlay
mv /tmp/overlay_script/overlay /etc/initramfs-tools/scripts/init-bottom/overlay

# 3. Генерация для целевого ядра
TARGET_KERNEL=\$(ls /lib/modules | sort -V | tail -n 1)
echo "Kernel: \$TARGET_KERNEL"

update-initramfs -c -k "\$TARGET_KERNEL"

# 4. Деплой
if [ -f "/boot/initrd.img-\$TARGET_KERNEL" ]; then
    cp "/boot/initrd.img-\$TARGET_KERNEL" /boot/firmware/initramfs8
else
    echo "ERROR: Initramfs failed"
    exit 1
fi

# --- В. ZRAM ---
apt-get install -y zram-tools
cat > /etc/default/zramswap <<ZRAMEOF
ALGO=zstd
PERCENT=50
PRIORITY=100
ZRAMEOF

# --- Г. СТАНДАРТНЫЕ НАСТРОЙКИ ---

echo "Generating Locales..."
apt-get install -y locales console-setup console-setup-linux
cat > /etc/locale.gen <<LOCALEEOF
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
LOCALEEOF
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Console (Применяем настройки, шрифты уже установлены)
setupcon --save-only

# Hostname & User
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

# Network
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

# Docker Log Limits
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<DOCKERCONF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "2m",
    "max-file": "2"
  }
}
DOCKERCONF

# Versioning
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

log_info "OS Configuration Complete."
