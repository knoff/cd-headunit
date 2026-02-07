#!/bin/bash
# STAGE 04: System Configuration (Native App Architecture)

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
cp -v "$WORKSPACE_DIR/system/udev/99-headunit-update.rules" /mnt/dst/etc/udev/rules.d/
cp -v "$WORKSPACE_DIR/system/systemd/rfkill-unblock.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/systemd/headunit-identity.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/systemd/headunit-update-monitor.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/systemd/headunit-update-monitor.path" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/systemd/headunit-update-usb-scan.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/systemd/headunit-kiosk.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/boot/keyboard" /mnt/dst/etc/default/keyboard
cp -v "$WORKSPACE_DIR/builder/assets/50-headunit-permissions.rules" /mnt/dst/etc/polkit-1/rules.d/

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

# 1. Генерируем дефолты
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

# === INTEGRATION: PYTHON PATH RESOLUTION ===
log_info "Configuring Python Path Resolution..."
# Создаем .pth файл, который добавляет путь к libraries активных сервисов
# Это позволяет импортировать библиотеки (например, cd_protocol), лежащие в Services Layer.
echo "/run/headunit/active_services/lib" > /mnt/dst/usr/lib/python3/dist-packages/headunit-services.pth
chmod 644 /mnt/dst/usr/lib/python3/dist-packages/headunit-services.pth
log_info "Created headunit-services.pth linkage."

# 3. Устанавливаем инструменты настройки
log_info "Installing System Tools..."
mkdir -p /mnt/dst/usr/local/bin

cp -v "$WORKSPACE_DIR/system/bin/headunit-config.py" /mnt/dst/usr/local/bin/headunit-config
chmod +x /mnt/dst/usr/local/bin/headunit-config

cp -v "$WORKSPACE_DIR/system/bin/headunit-apply-config.py" /mnt/dst/usr/local/bin/headunit-apply-config
chmod +x /mnt/dst/usr/local/bin/headunit-apply-config

cp -v "$WORKSPACE_DIR/system/bin/headunit-update-agent.py" /mnt/dst/usr/local/bin/headunit-update-agent
chmod +x /mnt/dst/usr/local/bin/headunit-update-agent



# Fix line endings (CRLF -> LF) for all python scripts
sed -i 's/\r$//' /mnt/dst/usr/local/bin/headunit-config
sed -i 's/\r$//' /mnt/dst/usr/local/bin/headunit-apply-config
sed -i 's/\r$//' /mnt/dst/usr/local/bin/headunit-update-agent

# === G. DATA RESIZE SERVICE ===
log_info "Installing Data Resize Service..."
cp -v "$WORKSPACE_DIR/system/scripts/resize-data" /mnt/dst/usr/local/bin/resize-data
chmod +x /mnt/dst/usr/local/bin/resize-data
cp -v "$WORKSPACE_DIR/system/systemd/resize-data.service" /mnt/dst/etc/systemd/system/resize-data.service

# === УСТАНОВКА BATS ===
log_info "Installing BATS Core..."
git clone https://github.com/bats-core/bats-core.git /tmp/bats
/tmp/bats/install.sh /mnt/dst/usr/local
rm -rf /tmp/bats

# Health Agent
log_info "Installing Health Agent..."
cp -v "$WORKSPACE_DIR/system/bin/health-agent.py" /mnt/dst/usr/local/bin/health-agent
chmod +x /mnt/dst/usr/local/bin/health-agent

# Копируем тесты
mkdir -p /mnt/dst/opt/headunit/tests/runtime
if [ -d "$WORKSPACE_DIR/system/tests/runtime" ]; then
    cp -v "$WORKSPACE_DIR/system/tests/runtime/"*.bats /mnt/dst/opt/headunit/tests/runtime/ 2>/dev/null || true
    cp -v "$WORKSPACE_DIR/system/tests/runtime/"*.bash /mnt/dst/opt/headunit/tests/runtime/ 2>/dev/null || true
    chmod +x /mnt/dst/opt/headunit/tests/runtime/*.bats 2>/dev/null || true
else
    log_warn "Runtime tests directory not found. Skipping."
fi

mkdir -p /mnt/dst/data
mkdir -p /mnt/dst/mnt/ram-overlay

# === MOUNT DATA PARTITION ===
# Мы должны примонтировать реальную Data партицию, чтобы mkdir/chown там сохранились
# LOOP_DST экспортирован из 01 stage, но прошло много времени.
# В 04 мы не знаем LOOP device напрямую, если он не передан.
# Но, обычно в пайплайне 01 экспортирует LOOP_DST.
# Однако, это разные скрипты. Переменные окружения между ними не шарятся автоматом если не через .env файл или единую сессию.
# build.sh запускает их последовательно.
# Давайте проверим loop device.

if [ -z "$LOOP_DST" ]; then
    # Fallback: ищем loop по файлу образа? Нет, так нельзя.
    # В build.sh мы делаем losetup один раз.
    # Проверим, доступен ли LOOP_DST.
    echo "Using Loop Device: $LOOP_DST"
fi

if [ -b "${LOOP_DST}p8" ]; then
    log_info "Mounting Data Partition (${LOOP_DST}p8)..."
    mount "${LOOP_DST}p8" /mnt/dst/data
else
    log_error "Data partition not found! Is LOOP_DST set?"
    # Если переменной нет, значит мы потеряли контекст.
    # В build.sh (который вызывает этот скрипт) LOOP_SRC/DST должны быть доступны.
fi

mkdir -p /mnt/dst/data/app
mkdir -p /mnt/dst/data/configs
mkdir -p /mnt/dst/data/db
mkdir -p /mnt/dst/data/components
mkdir -p /mnt/dst/data/incoming_updates


# Убеждаемся, что права на Data настроены на пользователя (чтобы SCP работал)
# Это выполняется ДО чрута, но пользователь внутри образа еще может не существовать c тем же UID?
# Лучше это делать в конце скрипта или внутри chroot если uid совпадают.
# Но проще сделать в конце скрипта, когда мы уже знаем $SYS_USER, но UID внутри образа
# может отличаться от хостового.
# Поэтому правильнее это делать ВНУТРИ chroot в конце.

# Здесь создаем только структуры


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
echo "Installing dependencies..."
# cloud-guest-utils (growpart), python3-venv/pip
apt-get install -y --no-install-recommends \
    initramfs-tools \
    zram-tools \
    locales \
    console-setup \
    console-common \
    console-data \
    fonts-terminus \
    fonts-noto-core \
    kbd \
    busybox-static \
    bc \
    python3 \
    python3-minimal \
    python3-venv \
    python3-pip \
    cloud-guest-utils \
    cage \
    chromium \
    libgl1-mesa-dri \
    seatd \
    xwayland

# Установка зависимостей из requirements.txt (единое окружение)
if [ -f "/opt/headunit/factory/services/requirements.txt" ]; then
    pip3 install --no-cache-dir -r /opt/headunit/factory/services/requirements.txt
fi

apt-get clean
rm -rf /var/lib/apt/lists/*

systemctl disable apt-daily.timer apt-daily-upgrade.timer man-db.timer
systemctl mask rpi-resize.service systemd-growfs-root.service rpi-resize-swap-file.service

# Активируем наш ресайз
systemctl enable resize-data.service

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
        usermod -aG sudo,video,render,input,netdev,plugdev,dialout,adm,systemd-journal,disk "$SYS_USER"
    fi
    echo "$SYS_USER:$SYS_PASS" | chpasswd
    echo "root:$SYS_PASS" | chpasswd
    if [ "$SYS_USER" != "pi" ] && id "pi" &>/dev/null; then
        pkill -u pi || true
        deluser --remove-home pi || true
    fi

    # Настройка Passwordless Sudo (с защитой mount)
    echo "Configuring Sudoers..."
    cat > /etc/sudoers.d/010_headunit-admin <<SUDOEOF
# HeadUnit Admin Rules
$SYS_USER ALL=(ALL) NOPASSWD: ALL
# Require password for critical FS operations
$SYS_USER ALL=(ALL) PASSWD: /usr/bin/mount, /bin/mount, /usr/sbin/mount
$SYS_USER ALL=(ALL) PASSWD: /usr/bin/umount, /bin/umount, /usr/sbin/umount
SUDOEOF
    chmod 0440 /etc/sudoers.d/010_headunit-admin
fi

# Настройка NetworkManager
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

mkdir -p /etc/NetworkManager/system-connections
chmod 700 /etc/NetworkManager/system-connections

if [ -n "$NET_WIFI_SSID" ]; then
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

if [ -n "$NET_AP_SSID" ]; then
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

chown root:root /etc/NetworkManager/system-connections/*.nmconnection

# --- H. DATA PERMISSIONS ---
mkdir -p /data/incoming_updates
chown -R $SYS_USER:$SYS_USER /data

EOF

# --- F. COMPONENT INSTALLATION (NATIVE) ---
log_info "Installing Application Components..."

# 1. Структура Factory
mkdir -p /mnt/dst/opt/headunit/factory/app
mkdir -p /mnt/dst/opt/headunit/factory/services
mkdir -p /mnt/dst/run/headunit

# 2. Копирование кода
# App
if [ -d "$WORKSPACE_DIR/src" ]; then
    cp -r "$WORKSPACE_DIR/src"/* /mnt/dst/opt/headunit/factory/app/

    # Cleanup frontend in factory image
    if [ -d "/mnt/dst/opt/headunit/factory/app/frontend" ]; then
        if [ -d "/mnt/dst/opt/headunit/factory/app/frontend/dist" ]; then
             log_info "Cleaning up factory frontend sources..."
             mv /mnt/dst/opt/headunit/factory/app/frontend/dist /tmp/dist_factory_tmp
             rm -rf /mnt/dst/opt/headunit/factory/app/frontend/*
             mv /tmp/dist_factory_tmp /mnt/dst/opt/headunit/factory/app/frontend/dist
        fi
    fi

    # Если нет манифеста, создаем дефолтный (защита от сбоя билда)
    if [ ! -f "/mnt/dst/opt/headunit/factory/app/manifest.json" ]; then
        echo '{"component":"app","version":"0.0.0","dependencies":{"services":">=0.0.0"}}' > /mnt/dst/opt/headunit/factory/app/manifest.json
    fi
fi

# Services
if [ -d "$WORKSPACE_DIR/services" ]; then
    cp -r "$WORKSPACE_DIR/services"/* /mnt/dst/opt/headunit/factory/services/
    if [ ! -f "/mnt/dst/opt/headunit/factory/services/manifest.json" ]; then
        echo '{"component":"services","version":"0.0.0","dependencies":{"os":">=0.0.0"}}' > /mnt/dst/opt/headunit/factory/services/manifest.json
    fi

    # Ensure executables in services/bin
    if [ -d "/mnt/dst/opt/headunit/factory/services/bin" ]; then
        chmod +x /mnt/dst/opt/headunit/factory/services/bin/* 2>/dev/null || true
        find /mnt/dst/opt/headunit/factory/services/bin -type f -exec sed -i 's/\r$//' {} + 2>/dev/null || true
    fi
fi

# 3. Boot Linker (Systemd & Script)
cp -v "$WORKSPACE_DIR/system/bin/headunit-boot-linker.py" /mnt/dst/usr/local/bin/headunit-boot-linker
chmod +x /mnt/dst/usr/local/bin/headunit-boot-linker
cp -v "$WORKSPACE_DIR/system/systemd/headunit-boot-linker.service" /mnt/dst/etc/systemd/system/
cp -v "$WORKSPACE_DIR/system/systemd/headunit-service-activator.service" /mnt/dst/etc/systemd/system/

# Активируем базовые системные сервисы
chroot /mnt/dst systemctl enable headunit-boot-linker.service
chroot /mnt/dst systemctl enable headunit-service-activator.service
chroot /mnt/dst systemctl enable headunit-update-monitor.path
chroot /mnt/dst systemctl enable headunit-kiosk.service

# --- G. VERSIONING & RELEASE FILE ---
# Обработка версий: убираем 'v' из тегов для внутренних нужд
# BUILD_VERSION приходит как 'v0.4.1-...'
# Очищаем: '0.4.1-...' (для OS_VERSION берем только базу)

# Clean OS Version (X.Y.Z)
CLEAN_OS_VER=$(echo "$BUILD_VERSION" | sed 's/^v//' | cut -d'-' -f1)

# Читаем версии из манифестов (если есть), иначе 0.0.0
APP_VER="0.0.0"
if [ -f "$WORKSPACE_DIR/src/manifest.json" ]; then
    APP_VER=$(grep '"version":' "$WORKSPACE_DIR/src/manifest.json" | cut -d'"' -f4)
fi

SVC_VER="0.0.0"
if [ -f "$WORKSPACE_DIR/services/manifest.json" ]; then
    SVC_VER=$(grep '"version":' "$WORKSPACE_DIR/services/manifest.json" | cut -d'"' -f4)
fi

log_info "Generating /etc/headunit-release..."
log_info "  Image: $BUILD_VERSION"
log_info "  OS: $CLEAN_OS_VER"
log_info "  App: $APP_VER"
log_info "  Services: $SVC_VER"

cat > /mnt/dst/etc/headunit-release <<VEREOF
NAME="HeadUnit OS"
ID=headunit
# Версия образа (для человека)
VERSION_ID="$BUILD_VERSION"
PRETTY_NAME="HeadUnit OS $BUILD_VERSION ($BUILD_MODE)"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Версии компонентов (для Boot Linker)
OS_VERSION="$CLEAN_OS_VER"
FACTORY_APP_VERSION="$APP_VER"
FACTORY_SERVICES_VERSION="$SVC_VER"
VEREOF

# Дублируем для совместимости с app
mkdir -p /mnt/dst/opt/headunit
cp /mnt/dst/etc/headunit-release /mnt/dst/opt/headunit/version.env

echo "Welcome to HeadUnit OS $BUILD_VERSION" > /mnt/dst/etc/motd

# 5. Уборка
rm -f /mnt/dst/usr/bin/qemu-aarch64-static
umount_safe /mnt/dst/proc
umount_safe /mnt/dst/sys
umount_safe /mnt/dst/dev/pts
umount_safe /mnt/dst/dev
umount_safe /mnt/dst/data

log_info "OS Configuration Complete."
