#!/bin/bash
# STAGE 04: System Configuration (Optimized Package Management + Font Fix)

log_step "04_sys_config.sh - Configuring OS Environment"

# 1. Подготовка (Binds)
log_info "Mounting system binds..."
cp /usr/bin/qemu-aarch64-static /mnt/dst/usr/bin/
mount_bind /dev /mnt/dst/dev
mount_bind /dev/pts /mnt/dst/dev/pts
mount_bind /sys /mnt/dst/sys
mount_bind /proc /mnt/dst/proc

# 2. Инъекция конфигов
log_info "Injecting configurations..."
cp -v "$WORKSPACE_DIR/system/udev/70-persistent-net.rules" /mnt/dst/etc/udev/rules.d/
cp -v "$WORKSPACE_DIR/system/udev/99-hide-partitions.rules" /mnt/dst/etc/udev/rules.d/
cp -v "$WORKSPACE_DIR/system/systemd/rfkill-unblock.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/boot/keyboard" /mnt/dst/etc/default/keyboard
# console-setup не копируем, создадим его с нуля ниже с правильным CODESET

# Скрипт оверлея
mkdir -p /mnt/dst/tmp/overlay_script
cp -v "$WORKSPACE_DIR/system/scripts/overlay-init" /mnt/dst/tmp/overlay_script/overlay

if command -v dos2unix >/dev/null 2>&1; then
    dos2unix /mnt/dst/tmp/overlay_script/overlay
else
    # Fallback если dos2unix нет на хосте, используем sed
    sed -i 's/\r$//' /mnt/dst/tmp/overlay_script/overlay
fi

# 3. Data папки
mkdir -p /mnt/dst/data/app
mkdir -p /mnt/dst/data/configs
mkdir -p /mnt/dst/data/db

# 4. CHROOT
export SYS_ENABLE_SSH SYS_USER SYS_PASS NET_HOSTNAME NET_WIFI_SSID NET_WIFI_PASS NET_WIFI_COUNTRY
export BUILD_VERSION BUILD_MODE

cat <<EOF | chroot /mnt/dst /bin/bash
set -e

# Отключаем интерактивность для чистого лога
export DEBIAN_FRONTEND=noninteractive

# === БЛОК 1: УПРАВЛЕНИЕ ПАКЕТАМИ ===
echo ">>> Managing Packages..."

apt-get update

# Удаление лишнего
apt-get remove -y userconf-pi cloud-init dphys-swapfile || true
rm -rf /usr/lib/userconf-pi /etc/cloud /var/lib/cloud /var/swap

# Установка зависимостей
# ВАЖНО: fonts-terminus обеспечивает шрифт, Uni2 требует console-setup
echo "Installing dependencies..."
apt-get install -y --no-install-recommends \
    initramfs-tools \
    zram-tools \
    locales \
    console-setup \
    console-common \
    console-data \
    fonts-terminus \
    kbd \
    busybox-static \
    bc

# Очистка
apt-get clean
rm -rf /var/lib/apt/lists/*

# Отключение сервисов
systemctl disable apt-daily.timer apt-daily-upgrade.timer man-db.timer
systemctl mask rpi-resize.service systemd-growfs-root.service rpi-resize-swap-file.service

# === БЛОК 2: НАСТРОЙКА ПОДСИСТЕМ ===

# --- A. INITRAMFS & OVERLAY ---
echo "Configuring Initramfs..."
if ! grep -q "overlay" /etc/initramfs-tools/modules; then
    echo "overlay" >> /etc/initramfs-tools/modules
fi

chmod +x /tmp/overlay_script/overlay
mv /tmp/overlay_script/overlay /etc/initramfs-tools/scripts/init-bottom/overlay

TARGET_KERNEL=\$(ls /lib/modules | sort -V | tail -n 1)
echo "Generating initramfs for \$TARGET_KERNEL..."
update-initramfs -c -k "\$TARGET_KERNEL"

if [ -f "/boot/initrd.img-\$TARGET_KERNEL" ]; then
    cp "/boot/initrd.img-\$TARGET_KERNEL" /boot/firmware/initramfs8
else
    echo "ERROR: Initramfs failed"
    exit 1
fi

# --- B. ZRAM ---
echo "Configuring ZRAM..."
cat > /etc/default/zramswap <<ZRAMEOF
ALGO=zstd
PERCENT=50
PRIORITY=100
ZRAMEOF

# --- C. LOCALES & CONSOLE ---
echo "Configuring Locales..."
cat > /etc/locale.gen <<LOCALEEOF
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
LOCALEEOF
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Console Setup
# ИСПРАВЛЕНИЕ: Uni2 вместо Guess. Uni2 = Universal (Latin + Cyrillic).
cat > /etc/default/console-setup <<FONTEOF
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Uni2"
FONTFACE="Terminus"
FONTSIZE="16x32"
FONTEOF

# Применяем настройки
# --save-only сгенерирует файлы в /etc/console-setup
setupcon --save-only

# --- D. USER & NETWORK ---
echo "Configuring System..."
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

# --- E. DOCKER LOGS ---
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

# --- F. VERSIONING ---
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

# 5. Уборка
rm -f /mnt/dst/usr/bin/qemu-aarch64-static
umount_safe /mnt/dst/proc
umount_safe /mnt/dst/sys
umount_safe /mnt/dst/dev/pts
umount_safe /mnt/dst/dev

log_info "OS Configuration Complete."
