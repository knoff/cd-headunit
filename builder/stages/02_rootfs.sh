#!/bin/bash
# STAGE 02: RootFS Cloning

log_step "02_rootfs.sh - Cloning Filesystem"

INPUT_IMG="$WORKSPACE_DIR/$INPUT_IMAGE_NAME"

# 1. Проверки
if [ ! -f "$INPUT_IMG" ]; then
    die "Input image not found: $INPUT_IMG"
fi

if [ -z "$LOOP_DST" ]; then
    die "Target loop device not found (LOOP_DST is empty). Stage 01 failed?"
fi

# 2. Подготовка Source (Исходник)
log_info "Mounting Source Image: $INPUT_IMAGE_NAME"
LOOP_SRC=$(losetup -fP --show "$INPUT_IMG")
export LOOP_SRC # Экспортируем для cleanap
refresh_partitions "$LOOP_SRC"

mkdir -p /mnt/src
mount_safe "${LOOP_SRC}p2" /mnt/src

# Определяем, где boot (в новых OS это /boot/firmware, в старых /boot)
if [ -d "/mnt/src/boot/firmware" ]; then
    log_info "Detected Bookworm/Trixie layout (/boot/firmware)"
    mount_safe "${LOOP_SRC}p1" /mnt/src/boot/firmware
else
    log_info "Detected Bullseye/Old layout (/boot)"
    mount_safe "${LOOP_SRC}p1" /mnt/src/boot
fi

# 3. Подготовка Target (Цель)
# Мы пишем только в Root A (p5). Root B и Factory в dev-режиме пропускаем.
log_info "Mounting Target Partitions..."

mkdir -p /mnt/dst
mount_safe "${LOOP_DST}p5" /mnt/dst        # Root A
mkdir -p /mnt/dst/boot/firmware
mount_safe "${LOOP_DST}p1" /mnt/dst/boot/firmware  # Boot

# 4. Клонирование (Rsync)
log_info "Starting Rsync (RootFS -> Root A)..."
# -a: archive mode, -H: hard links, -A: ACLs, -X: xattrs
# Исключаем временные файлы и само содержимое boot (оно копируется отдельно или монтируется)
rsync -aHAX --info=progress2 \
    --exclude='/boot/firmware/*' \
    --exclude='/boot/*' \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/dev/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    --exclude='/mnt/*' \
    /mnt/src/ /mnt/dst/

log_info "Syncing Boot partition..."
# Если исходник был смонтирован в firmware, копируем его содержимое
if mountpoint -q /mnt/src/boot/firmware; then
    rsync -aHAX /mnt/src/boot/firmware/ /mnt/dst/boot/firmware/
else
    # Fallback для старых систем
    rsync -aHAX /mnt/src/boot/ /mnt/dst/boot/firmware/
fi

# 5. Клонирование в Root B / Factory (Только для PROD)
if [ "$BUILD_MODE" == "user" ]; then
    log_info "[USER MODE] Cloning into Root B and Factory..."

    mkdir -p /mnt/dst_b
    mount_safe "${LOOP_DST}p6" /mnt/dst_b
    rsync -aHAX /mnt/dst/ /mnt/dst_b/
    umount_safe /mnt/dst_b

    mkdir -p /mnt/dst_fact
    mount_safe "${LOOP_DST}p7" /mnt/dst_fact
    # Factory часто делают как tar-архив для восстановления
    log_info "Creating Factory Tarball..."
    tar -cf /mnt/dst_fact/rootfs.tar -C /mnt/dst .
    umount_safe /mnt/dst_fact
else
    log_info "[DEV MODE] Skipping clone to Root B/Factory (Stubs only)"
fi

# 6. Очистка Source (Target оставляем смонтированным для Stage 03)
umount_safe /mnt/src/boot/firmware
umount_safe /mnt/src/boot
umount_safe /mnt/src
losetup -d "$LOOP_SRC"
unset LOOP_SRC

log_info "Cloning Complete."
