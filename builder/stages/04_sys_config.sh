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
cp -v "$WORKSPACE_DIR/system/systemd/headunit-identity.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/boot/keyboard" /mnt/dst/etc/default/keyboard
# console-setup не копируем, создадим его с нуля ниже с правильным CODESET

# Скрипт оверлея
mkdir -p /mnt/dst/tmp/overlay_script
cp -v "$WORKSPACE_DIR/system/scripts/overlay-init" /mnt/dst/tmp/overlay_script/overlay

if command -v dos2unix >/dev/null 2>&1; then
    dos2unix /mnt/dst/tmp/overlay_script/overlay
else
    sed -i 's/\r$//' /mnt/dst/tmp/overlay_script/overlay
fi

# === CONFIGURATION & DEFAULTS ===
log_info "Generating Factory Defaults..."
mkdir -p /mnt/dst/etc/headunit

# 1. Генерируем дефолты из переменных сборки
# Используем NET_AP_SSID как Serial по умолчанию, если он не задан отдельно
cat > /mnt/dst/etc/headunit/factory_defaults.json <<JSONEOF
{
  "serial": "${NET_AP_SSID:-CDR-00000000}",
  "wifi_ap_pass": "${NET_AP_PASS}",
  "wifi_client_ssid": "${NET_WIFI_SSID}",
  "wifi_client_pass": "${NET_WIFI_PASS}",
  "wifi_country": "${NET_WIFI_COUNTRY:-RU}"
}
JSONEOF
chmod 644 /mnt/dst/etc/headunit/factory_defaults.json

# 2. Устанавливаем библиотеку конфигурации
log_info "Installing Shared Libraries..."
cp -v "$WORKSPACE_DIR/system/lib/hu_config.py" /mnt/dst/usr/lib/python3/dist-packages/hu_config.py
chmod 644 /mnt/dst/usr/lib/python3/dist-packages/hu_config.py

# 3. Устанавливаем инструменты настройки
log_info "Installing System Tools..."
mkdir -p /mnt/dst/usr/local/bin

cp -v "$WORKSPACE_DIR/system/bin/headunit-config.py" /mnt/dst/usr/local/bin/headunit-config
chmod +x /mnt/dst/usr/local/bin/headunit-config

cp -v "$WORKSPACE_DIR/system/bin/headunit-apply-config.py" /mnt/dst/usr/local/bin/headunit-apply-config
chmod +x /mnt/dst/usr/local/bin/headunit-apply-config

# === УСТАНОВКА BATS (Testing Framework) ===
log_info "Installing BATS Core..."
# Клонируем и ставим (самый надежный способ для embedded, чтобы не тянуть лишние зависимости apt)
git clone https://github.com/bats-core/bats-core.git /tmp/bats
/tmp/bats/install.sh /mnt/dst/usr/local
rm -rf /tmp/bats

# Проверка (на всякий случай)
if [ ! -x "/mnt/dst/usr/local/bin/bats" ]; then
    die "BATS installation failed!"
fi

# Health Agent
log_info "Installing Health Agent..."
cp -v "$WORKSPACE_DIR/system/bin/health-agent.py" /mnt/dst/usr/local/bin/health-agent
chmod +x /mnt/dst/usr/local/bin/health-agent

# Копируем тесты
mkdir -p /mnt/dst/opt/headunit/tests/runtime
if [ -d "$WORKSPACE_DIR/system/tests/runtime" ]; then
    # Копируем только .sh файлы, чтобы не тянуть мусор
    cp -v "$WORKSPACE_DIR/system/tests/runtime/"*.bats /mnt/dst/opt/headunit/tests/runtime/ 2>/dev/null || true
    cp -v "$WORKSPACE_DIR/system/tests/runtime/"*.bash /mnt/dst/opt/headunit/tests/runtime/ 2>/dev/null || true

    chmod +x /mnt/dst/opt/headunit/tests/runtime/*.bats 2>/dev/null || true
else
    log_warn "Runtime tests directory not found. Skipping."
fi
# ========================================

# 3. Data папки
mkdir -p /mnt/dst/data/app
mkdir -p /mnt/dst/data/configs
mkdir -p /mnt/dst/data/db

# 4. CHROOT
export SYS_ENABLE_SSH SYS_USER SYS_PASS NET_HOSTNAME NET_WIFI_COUNTRY
export NET_WIFI_SSID NET_WIFI_PASS
export NET_AP_SSID NET_AP_PASS NET_AP_IP
export BUILD_VERSION BUILD_MODE SERIAL

cat <<EOF | chroot /mnt/dst /bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# === БЛОК 1: УПРАВЛЕНИЕ ПАКЕТАМИ ===
echo ">>> Managing Packages..."
apt-get update

# Удаление лишнего
apt-get remove -y userconf-pi cloud-init dphys-swapfile || true
rm -rf /usr/lib/userconf-pi /etc/cloud /var/lib/cloud /var/swap

# Установка зависимостей
# Добавляем python3 для работы агента (обычно он есть, но для надежности)
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
    bc \
    python3 \
    python3-minimal

apt-get clean
rm -rf /var/lib/apt/lists/*

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

cat > /etc/default/console-setup <<FONTEOF
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Uni2"
FONTFACE="Terminus"
FONTSIZE="16x32"
FONTEOF
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

# Настройка NetworkManager
systemctl enable NetworkManager
systemctl disable wpa_supplicant
systemctl stop wpa_supplicant || true
rm -f /var/lib/NetworkManager/NetworkManager.state
systemctl enable rfkill-unblock.service
systemctl unmask systemd-rfkill.service || true

# Глобальная настройка WiFi (Country Code)
if [ -n "$NET_WIFI_COUNTRY" ]; then
    mkdir -p /etc/wpa_supplicant
    echo "country=$NET_WIFI_COUNTRY" > /etc/wpa_supplicant/wpa_supplicant.conf
fi

mkdir -p /etc/NetworkManager/system-connections
chmod 700 /etc/NetworkManager/system-connections

# 1. External WiFi (Client) -> wlan1
if [ -n "$NET_WIFI_SSID" ]; then
    echo "Creating Static Client Config..."
    UUID_CLIENT=\$(cat /proc/sys/kernel/random/uuid)
    cat > "/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection" <<NMEOF
[connection]
id=preconfigured-wifi
uuid=\$UUID_CLIENT
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
fi

# 2. Internal WiFi (AP) -> wlan0
if [ -n "$NET_AP_SSID" ]; then
    echo "Creating Static AP Config..."
    UUID_AP=\$(cat /proc/sys/kernel/random/uuid)
    cat > "/etc/NetworkManager/system-connections/internal-ap.nmconnection" <<NMEOF
[connection]
id=internal-ap
uuid=\$UUID_AP
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=ap
ssid=$NET_AP_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$NET_AP_PASS

[ipv4]
method=shared
address1=$NET_AP_IP

[ipv6]
addr-gen-mode=default
method=ignore
NMEOF
    chmod 600 "/etc/NetworkManager/system-connections/internal-ap.nmconnection"
fi

# Исправление прав (на всякий случай массово)
chown root:root /etc/NetworkManager/system-connections/*.nmconnection

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

# --- G. HEALTH CHECK SERVICE ---
# Создаем systemd юнит для запуска тестов при старте (опционально, если нужно)
# Пока просто оставляем бинарник доступным для ручного запуска или через deploy.ps1

EOF

# 5. Уборка
rm -f /mnt/dst/usr/bin/qemu-aarch64-static
umount_safe /mnt/dst/proc
umount_safe /mnt/dst/sys
umount_safe /mnt/dst/dev/pts
umount_safe /mnt/dst/dev

log_info "OS Configuration Complete."
