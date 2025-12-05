#!/bin/bash
set -e

# ================= UTILS =================
log() { echo -e "\033[1;32m[BUILDER][$BUILD_MODE]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }

# ================= CONFIGURATION LOAD =================
BUILD_MODE="${BUILD_MODE:-dev}"
CONF_FILE="/workspace/builder/headunit.conf"
CONF_EXAMPLE="/workspace/builder/headunit.conf.example"

if [ -f "$CONF_EXAMPLE" ]; then source "$CONF_EXAMPLE"; fi
if [ -f "$CONF_FILE" ]; then
    log "Loading local configuration from headunit.conf..."
    source "$CONF_FILE"
else
    warn "Local config not found. Using defaults."
fi

# Defaults
USER_NAME="${USER_NAME:-cdreborn}"
USER_PASS="${USER_PASS:-brewme}"
SIZE_BOOT="${SIZE_BOOT:-512}"
SIZE_ROOT="${SIZE_ROOT:-3072}"
SIZE_FACTORY="${SIZE_FACTORY:-2048}"
SIZE_DATA="${SIZE_DATA:-512}"

# Имена файлов
INPUT_IMG="/workspace/${INPUT_IMAGE}"
OUTPUT_IMG="/workspace/headunit-${BUILD_MODE}-v1.img"

refresh_partitions() {
    local loopdev="$1"
    partprobe "$loopdev" || true
    sleep 1
    local loopname=$(basename "$loopdev")
    for part_dir in /sys/class/block/${loopname}p*; do
        if [ -d "$part_dir" ]; then
            local partname=$(basename "$part_dir")
            local devnode="/dev/$partname"
            if [ ! -b "$devnode" ]; then
                local dev_numerals=$(cat "$part_dir/dev")
                local major=${dev_numerals%%:*}
                local minor=${dev_numerals##*:}
                mknod "$devnode" b "$major" "$minor"
            fi
        fi
    done
}

cleanup() {
    log "Cleaning up mounts..."
    if mountpoint -q /mnt/dst/sys; then umount /mnt/dst/sys; fi
    if mountpoint -q /mnt/dst/proc; then umount /mnt/dst/proc; fi
    if mountpoint -q /mnt/dst/dev/pts; then umount /mnt/dst/dev/pts; fi
    if mountpoint -q /mnt/dst/dev; then umount /mnt/dst/dev; fi
    if mountpoint -q /mnt/dst/boot/firmware; then umount /mnt/dst/boot/firmware; fi

    if mountpoint -q /mnt/src/boot/firmware; then umount /mnt/src/boot/firmware; fi
    if mountpoint -q /mnt/src/boot; then umount /mnt/src/boot; fi

    if [ -d "/mnt/src" ]; then umount -R /mnt/src 2>/dev/null || true; fi
    if [ -d "/mnt/dst" ]; then umount -R /mnt/dst 2>/dev/null || true; fi
    if [ -d "/mnt/dst_b" ]; then umount -R /mnt/dst_b 2>/dev/null || true; fi
    if [ -d "/mnt/dst_fact" ]; then umount -R /mnt/dst_fact 2>/dev/null || true; fi
    if [ -d "/mnt/dst_data" ]; then umount -R /mnt/dst_data 2>/dev/null || true; fi

    if [ -n "$LOOP_SRC" ]; then losetup -d "$LOOP_SRC" 2>/dev/null || true; fi
    if [ -n "$LOOP_DST" ]; then losetup -d "$LOOP_DST" 2>/dev/null || true; fi
}
trap cleanup EXIT

# ================= CHECKS =================
if [ ! -f "$INPUT_IMG" ]; then error "Input image $INPUT_IMG not found!"; fi

# ================= STEP 1: PREPARE SOURCE =================
log "Setting up source image..."
LOOP_SRC=$(losetup -fP --show "$INPUT_IMG")
refresh_partitions "$LOOP_SRC"

mkdir -p /mnt/src
mount "${LOOP_SRC}p2" /mnt/src
if [ -d "/mnt/src/boot/firmware" ]; then
    mount "${LOOP_SRC}p1" /mnt/src/boot/firmware
else
    mount "${LOOP_SRC}p1" /mnt/src/boot
fi

# ================= STEP 2: CREATE TARGET IMAGE =================
TOTAL_SIZE=$((SIZE_BOOT + 1 + SIZE_ROOT + 1 + SIZE_ROOT + 1 + SIZE_FACTORY + 1 + SIZE_DATA + 100))
log "Creating target image size: ${TOTAL_SIZE}MB"

dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=0 seek="$TOTAL_SIZE" status=none

log "Partitioning target image (MBR with Extended)..."
parted -s "$OUTPUT_IMG" mklabel msdos
parted -s "$OUTPUT_IMG" mkpart primary fat32 1MiB "$((SIZE_BOOT + 1))"MiB
parted -s "$OUTPUT_IMG" set 1 lba on
EXT_START=$((SIZE_BOOT + 1))
parted -s "$OUTPUT_IMG" mkpart extended "${EXT_START}MiB" 100%

# Logical partitions (+1MB gap)
START_P5=$((EXT_START + 1)); END_P5=$((START_P5 + SIZE_ROOT))
START_P6=$((END_P5 + 1));     END_P6=$((START_P6 + SIZE_ROOT))
START_P7=$((END_P6 + 1));     END_P7=$((START_P7 + SIZE_FACTORY))
START_P8=$((END_P7 + 1));     END_P8=$((TOTAL_SIZE - 1))

parted -s "$OUTPUT_IMG" mkpart logical ext4 "${START_P5}MiB" "${END_P5}MiB" # Root A
parted -s "$OUTPUT_IMG" mkpart logical ext4 "${START_P6}MiB" "${END_P6}MiB" # Root B
parted -s "$OUTPUT_IMG" mkpart logical ext4 "${START_P7}MiB" "${END_P7}MiB" # Factory
parted -s "$OUTPUT_IMG" mkpart logical ext4 "${START_P8}MiB" 100%           # Data

LOOP_DST=$(losetup -fP --show "$OUTPUT_IMG")
refresh_partitions "$LOOP_DST"

# ================= STEP 3: FORMATTING =================
log "Formatting partitions..."
mkfs.vfat -F 32 -n BOOT "${LOOP_DST}p1" >/dev/null
mkfs.ext4 -q -L rootfs_A "${LOOP_DST}p5"
mkfs.ext4 -q -L rootfs_B "${LOOP_DST}p6"
mkfs.ext4 -q -L factory "${LOOP_DST}p7"
mkfs.ext4 -q -L data "${LOOP_DST}p8"

# ================= STEP 4: CLONING ROOT A =================
mkdir -p /mnt/dst
mount "${LOOP_DST}p5" /mnt/dst
mkdir -p /mnt/dst/boot/firmware

log "Cloning RootFS -> Root A..."
rsync -aHAX --info=progress2 --exclude='/boot/firmware/*' --exclude='/boot/*' /mnt/src/ /mnt/dst/

log "Cloning Boot partition..."
BOOT_MOUNT="/boot"
if [ -d "/mnt/dst/boot/firmware" ]; then
    mount "${LOOP_DST}p1" /mnt/dst/boot/firmware
    BOOT_MOUNT="/boot/firmware"
    if mountpoint -q /mnt/src/boot/firmware; then
        rsync -aHAX /mnt/src/boot/firmware/ /mnt/dst/boot/firmware/
    else
        rsync -aHAX /mnt/src/boot/ /mnt/dst/boot/firmware/
    fi
else
    mount "${LOOP_DST}p1" /mnt/dst/boot
    rsync -aHAX /mnt/src/boot/ /mnt/dst/boot/
fi

# ================= STEP 5: CONDITIONAL CLONING =================
if [ "$BUILD_MODE" == "user" ]; then
    log "[USER] Cloning Root B and Factory..."
    mkdir -p /mnt/dst_b
    mount "${LOOP_DST}p6" /mnt/dst_b
    rsync -aHAX /mnt/dst/ /mnt/dst_b/
    umount /mnt/dst_b

    mkdir -p /mnt/dst_fact
    mount "${LOOP_DST}p7" /mnt/dst_fact
    tar -cf /mnt/dst_fact/rootfs.tar -C /mnt/dst .
    sha256sum /mnt/dst_fact/rootfs.tar > /mnt/dst_fact/rootfs.tar.sha256
    umount /mnt/dst_fact
else
    log "[DEV] Skipping Root B/Factory clone."
fi

# Data structure
mkdir -p /mnt/dst_data
mount "${LOOP_DST}p8" /mnt/dst_data
mkdir -p /mnt/dst_data/var_lib_docker
mkdir -p /mnt/dst_data/var_log
mkdir -p /mnt/dst_data/configs
umount /mnt/dst_data

# ================= STEP 6: CHROOT CONFIGURATION =================
log "Preparing Chroot Environment..."

mount --bind /dev /mnt/dst/dev
mount --bind /dev/pts /mnt/dst/dev/pts
mount --bind /proc /mnt/dst/proc
mount --bind /sys /mnt/dst/sys
cp /usr/bin/qemu-aarch64-static /mnt/dst/usr/bin/

# Передаем переменные внутрь chroot
export USER_NAME USER_PASS WIFI_SSID WIFI_PASS WIFI_COUNTRY AP_SSID AP_PASS AP_IP BUILD_MODE

cat <<EOF | chroot /mnt/dst /bin/bash
set -e

echo "Removing default 'pi' user and wizard..."

# Удаляем пользователя pi, если он существует
if id "pi" &>/dev/null; then
    pkill -u pi || true
    deluser --remove-home pi
fi

# Отключаем сервис настройки пользователя (userconf-pi)
if systemctl list-unit-files | grep -q userconf-pi; then
    systemctl disable userconf-pi
fi
# Для надежности удаляем сам скрипт инициализации, если он есть (пока оставим заглушкой)
rm -f /etc/init.d/userconf-pi
 rm -f /usr/lib/systemd/system/userconf-pi.service
# Иногда бывает симлинк в /etc/systemd/system/sysinit.target.wants/
 rm -f /etc/systemd/system/sysinit.target.wants/userconf-pi.service

# Удаляем (переименовываем) файл, который иногда триггерит настройку (в старых версиях, но не помешает)
[ -f /boot/userconf.txt ] && mv /boot/userconf.txt /boot/userconf.txt.del || true
[ -f /boot/firmware/userconf.txt ] && mv /boot/firmware/userconf.txt /boot/firmware/userconf.txt.del || true


# 1. Пользователь
if ! id "$USER_NAME" &>/dev/null; then
    echo "Creating user $USER_NAME..."
    useradd -m -s /bin/bash "$USER_NAME"
    usermod -aG sudo,video,render,input "$USER_NAME"
fi
echo "$USER_NAME:$USER_PASS" | chpasswd
echo "root:$USER_PASS" | chpasswd

# 2. Hostname
echo "headunit" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "127.0.1.1 headunit" >> /etc/hosts

# 3. Отключение авто-ресайза
if [ -f /etc/init.d/resize2fs_once ]; then
    update-rc.d resize2fs_once remove
    rm /etc/init.d/resize2fs_once
fi
systemctl disable resize2fs_once 2>/dev/null || true
systemctl disable rpi-resize 2>/dev/null || true
systemctl mask systemd-growfs-root

# 4. SSH
systemctl enable ssh

# 5. Environment
echo "CD_BUILD_MODE=$BUILD_MODE" >> /etc/environment

# 6. NetworkManager Configuration
echo "Configuring NetworkManager..."

# Обеспечиваем права 600 для секретов
mkdir -p /etc/NetworkManager/system-connections
chmod 700 /etc/NetworkManager/system-connections

# Генерация Wi-Fi Client (wlan0)
if [ -n "$WIFI_SSID" ]; then
    echo "Adding Wi-Fi Client: $WIFI_SSID"
    UUID_CLIENT=\$(cat /proc/sys/kernel/random/uuid)
    cat > "/etc/NetworkManager/system-connections/wifi-client.nmconnection" <<NMEOF
[connection]
id=wifi-client
uuid=\$UUID_CLIENT
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$WIFI_PASS

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto
NMEOF
    chmod 600 "/etc/NetworkManager/system-connections/wifi-client.nmconnection"
fi

# Генерация Access Point (wlan1)
if [ -n "$AP_SSID" ]; then
    echo "Adding Access Point: $AP_SSID on wlan1"
    UUID_AP=\$(cat /proc/sys/kernel/random/uuid)
    cat > "/etc/NetworkManager/system-connections/wifi-ap.nmconnection" <<NMEOF
[connection]
id=wifi-ap
uuid=\$UUID_AP
type=wifi
interface-name=wlan1
autoconnect=true

[wifi]
mode=ap
ssid=$AP_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$AP_PASS

[ipv4]
method=shared
address1=$AP_IP

[ipv6]
addr-gen-mode=default
method=disabled
NMEOF
    chmod 600 "/etc/NetworkManager/system-connections/wifi-ap.nmconnection"
fi

EOF

rm /mnt/dst/usr/bin/qemu-aarch64-static

# ================= STEP 7: FSTAB & CMDLINE =================
log "Configuring Fstab and Cmdline..."

UUID_BOOT=$(blkid -s PARTUUID -o value "${LOOP_DST}p1")
UUID_ROOTA=$(blkid -s PARTUUID -o value "${LOOP_DST}p5")
UUID_ROOTB=$(blkid -s PARTUUID -o value "${LOOP_DST}p6")
UUID_DATA=$(blkid -s PARTUUID -o value "${LOOP_DST}p8")
UUID_FACTORY=$(blkid -s PARTUUID -o value "${LOOP_DST}p7")

cat > /mnt/dst/etc/fstab <<EOF
proc            /proc           proc    defaults          0       0
PARTUUID=$UUID_BOOT   $BOOT_MOUNT     vfat    defaults          0       2
PARTUUID=$UUID_ROOTA  /               ext4    defaults,noatime  0       1
PARTUUID=$UUID_FACTORY /factory       ext4    defaults,ro,nofail 0       2
PARTUUID=$UUID_DATA   /data           ext4    defaults,noatime,nofail  0       2
PARTUUID=$UUID_ROOTB  /mnt/root_b     ext4    defaults,noauto   0       2

tmpfs   /tmp    tmpfs   defaults,noatime,mode=1777 0 0
tmpfs   /var/log tmpfs  defaults,noatime,mode=0755 0 0
EOF

if [ "$BUILD_MODE" == "user" ]; then
    mkdir -p /mnt/dst_b
    mount "${LOOP_DST}p6" /mnt/dst_b
    cp /mnt/dst/etc/fstab /mnt/dst_b/etc/fstab
    sed -i "s/$UUID_ROOTA/$UUID_ROOTB/" /mnt/dst_b/etc/fstab
    umount /mnt/dst_b
fi

CMDLINE="/mnt/dst${BOOT_MOUNT}/cmdline.txt"
if [ ! -f "$CMDLINE" ]; then CMDLINE=$(find /mnt/dst/boot -name cmdline.txt | head -n 1); fi

ORIG_CMD=$(cat "$CMDLINE")
CLEAN_CMD=$(echo "$ORIG_CMD" | sed -E 's/root=PARTUUID=[^ ]+//g' | sed -E 's/init=[^ ]+//g' | sed 's/quiet//g' | sed 's/splash//g')

echo "console=serial0,115200 console=tty1 root=PARTUUID=$UUID_ROOTA rootfstype=ext4 fsck.repair=yes rootwait quiet splash logo.nologo vt.global_cursor_default=0" > "$CMDLINE"

# ================= STEP 8: FINALIZE =================
log "Finalizing..."
umount -R /mnt/dst
log "Build complete: $OUTPUT_IMG"
