#!/bin/bash
# STAGE 03: Boot Configuration (OverlayFS RAM Mode)

log_step "03_boot_config.sh - Configuring Bootloader"

UUID_BOOT=$(blkid -s PARTUUID -o value "${LOOP_DST}p1")
UUID_ROOT_A=$(blkid -s PARTUUID -o value "${LOOP_DST}p5")
UUID_ROOT_B=$(blkid -s PARTUUID -o value "${LOOP_DST}p6")
UUID_FACTORY=$(blkid -s PARTUUID -o value "${LOOP_DST}p7")
UUID_DATA=$(blkid -s PARTUUID -o value "${LOOP_DST}p8")

log_info "Writing /etc/fstab..."
FSTAB_BOOT="/boot/firmware"
if [ ! -d "/mnt/dst/boot/firmware" ]; then FSTAB_BOOT="/boot"; fi

# ВАЖНОЕ ИЗМЕНЕНИЕ В FSTAB:
# 1. Для корня (/) убираем 'ro' и ставим 'defaults'.
#    Система будет видеть корень как RW (благодаря OverlayFS в RAM).
# 2. Data оставляем.
cat > /mnt/dst/etc/fstab <<EOF
proc            /proc           proc    defaults          0       0
PARTUUID=$UUID_BOOT   $FSTAB_BOOT     vfat    defaults,ro       0       2

# System Root: Systemd должен считать, что это RW (пишем в RAM)
PARTUUID=$UUID_ROOT_A /               ext4    defaults,noatime  0       1

# Data Partition (Through-hole)
PARTUUID=$UUID_DATA   /data           ext4    defaults,noatime,commit=600,nofail  0       2

# Spare Partitions
PARTUUID=$UUID_FACTORY /factory       ext4    defaults,ro,noauto,nofail       0       2
PARTUUID=$UUID_ROOT_B  /mnt/root_b    ext4    defaults,ro,noauto,nofail       0       2
EOF

# CMDLINE:
# Убираем 'ro' из параметров ядра, чтобы initramfs не монтировал корень как ro глобально.
# Физический раздел останется ro, так как overlay-init скрипт не делает 'mount -o remount,rw'.
CMDLINE_FILE="/mnt/dst/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE_FILE" ]; then CMDLINE_FILE="/mnt/dst/boot/cmdline.txt"; fi

if [ -f "$CMDLINE_FILE" ]; then
    log_info "Updating kernel args..."
    ORIG_CMD=$(cat "$CMDLINE_FILE")
    CLEAN_CMD=$(echo "$ORIG_CMD" | sed -E 's/root=PARTUUID=[^ ]+//g' | sed -E 's/init=[^ ]+//g' | sed -E 's/fsck.repair=[^ ]+//g')

    # Убрали 'ro'. Добавили 'fastboot' (пропуск fsck, т.к. раздел ro).
    NEW_CMD="console=serial0,115200 console=tty1 root=PARTUUID=$UUID_ROOT_A rootfstype=ext4 fsck.mode=skip noswap rootwait"
    echo "$NEW_CMD $CLEAN_CMD" > "$CMDLINE_FILE"
fi

# CONFIG.TXT
CONFIG_TXT="/mnt/dst/boot/firmware/config.txt"
if [ ! -f "$CONFIG_TXT" ]; then CONFIG_TXT="/mnt/dst/boot/config.txt"; fi

log_info "Enabling Initramfs..."
sed -i 's/^auto_initramfs=/#auto_initramfs=/' "$CONFIG_TXT"

if ! grep -q "initramfs initramfs8" "$CONFIG_TXT"; then
    echo "" >> "$CONFIG_TXT"
    echo "[all]" >> "$CONFIG_TXT"
    echo "initramfs initramfs8 followkernel" >> "$CONFIG_TXT"
fi

log_info "Boot configuration updated."
