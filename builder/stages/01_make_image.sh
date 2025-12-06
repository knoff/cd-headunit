#!/bin/bash
# STAGE 01: Image Creation and Partitioning

log_step "01_make_image.sh - Creating Disk Image"

# 1. Расчет размера образа
# Суммируем размеры разделов + 4MB на MBR/Padding + запас
TOTAL_SIZE=$((PART_BOOT_SIZE + PART_ROOT_A_SIZE + PART_ROOT_B_SIZE + PART_FACTORY_SIZE + PART_DATA_SIZE + 50))

OUTPUT_FILE="${WORKSPACE_DIR}/${IMAGE_NAME}-${BUILD_MODE}.img"
if [ -n "$TARGET_FILENAME" ]; then
    OUTPUT_FILE="${WORKSPACE_DIR}/${TARGET_FILENAME}"
else
    OUTPUT_FILE="${WORKSPACE_DIR}/${IMAGE_NAME}-${BUILD_MODE}.img"
fi
# =======================

log_info "Target Image: $OUTPUT_FILE"
log_info "Target Size: ${TOTAL_SIZE} MB"
log_info "Layout: Boot=${PART_BOOT_SIZE}, A=${PART_ROOT_A_SIZE}, B=${PART_ROOT_B_SIZE}, Fact=${PART_FACTORY_SIZE}, Data=${PART_DATA_SIZE}"

# 2. Создание пустого файла
dd if=/dev/zero of="$OUTPUT_FILE" bs=1M count=0 seek="$TOTAL_SIZE" status=none

# 3. Разметка диска (parted)
# Используем MiB для точного выравнивания
log_info "Partitioning (MBR + Extended)..."

parted -s "$OUTPUT_FILE" mklabel msdos

# --- Primary: Boot ---
# Start: 1MiB (выравнивание)
# End: 1 + BOOT
P1_START=1
P1_END=$((P1_START + PART_BOOT_SIZE))
parted -s "$OUTPUT_FILE" mkpart primary fat32 "${P1_START}MiB" "${P1_END}MiB"
parted -s "$OUTPUT_FILE" set 1 lba on

# --- Extended Partition Container ---
# Занимает все оставшееся место
EXT_START=$((P1_END + 1))
parted -s "$OUTPUT_FILE" mkpart extended "${EXT_START}MiB" 100%

# --- Logical Partitions ---
# Внутри Extended (нужен зазор 1MB между метаданными extended и первым логическим)

# Root A (p5)
P5_START=$((EXT_START + 1))
P5_END=$((P5_START + PART_ROOT_A_SIZE))
parted -s "$OUTPUT_FILE" mkpart logical ext4 "${P5_START}MiB" "${P5_END}MiB"

# Root B (p6)
P6_START=$((P5_END + 1))
P6_END=$((P6_START + PART_ROOT_B_SIZE))
parted -s "$OUTPUT_FILE" mkpart logical ext4 "${P6_START}MiB" "${P6_END}MiB"

# Factory (p7)
P7_START=$((P6_END + 1))
P7_END=$((P7_START + PART_FACTORY_SIZE))
parted -s "$OUTPUT_FILE" mkpart logical ext4 "${P7_START}MiB" "${P7_END}MiB"

# Data (p8)
P8_START=$((P7_END + 1))
# Data занимает все до конца (минус небольшой хвост, чтобы не вылезти за границы)
parted -s "$OUTPUT_FILE" mkpart logical ext4 "${P8_START}MiB" 100%

# 4. Loop setup
LOOP_DST=$(losetup -fP --show "$OUTPUT_FILE")
export LOOP_DST # Экспортируем, чтобы следующие этапы видели переменную
refresh_partitions "$LOOP_DST"

# 5. Форматирование
log_info "Formatting partitions..."
mkfs.vfat -F 32 -n BOOT "${LOOP_DST}p1" >/dev/null
mkfs.ext4 -q -L rootfs_A "${LOOP_DST}p5"
mkfs.ext4 -q -L rootfs_B "${LOOP_DST}p6"
mkfs.ext4 -q -L factory "${LOOP_DST}p7"
mkfs.ext4 -q -L data "${LOOP_DST}p8"

log_info "Image created and mounted at $LOOP_DST"
