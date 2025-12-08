#!/bin/bash
# STAGE 03: Boot Configuration (OverlayFS Custom Hook)

log_step "03_boot_config.sh - Configuring Bootloader"

UUID_BOOT=$(blkid -s PARTUUID -o value "${LOOP_DST}p1")
UUID_ROOT_A=$(blkid -s PARTUUID -o value "${LOOP_DST}p5")
UUID_ROOT_B=$(blkid -s PARTUUID -o value "${LOOP_DST}p6")
UUID_FACTORY=$(blkid -s PARTUUID -o value "${LOOP_DST}p7")
UUID_DATA=$(blkid -s PARTUUID -o value "${LOOP_DST}p8")

log_info "Writing /etc/fstab..."
FSTAB_BOOT="/boot/firmware"
if [ ! -d "/mnt/dst/boot/firmware" ]; then FSTAB_BOOT="/boot"; fi

# FSTAB:
# Только физические разделы.
# Корень (/) монтируется ядром как RO.
# Data (/data) монтируется нашим скриптом initramfs, но оставим запись здесь для systemd (он поймет, что уже смонтировано).
cat > /mnt/dst/etc/fstab <<EOF
proc            /proc           proc    defaults          0       0
PARTUUID=$UUID_BOOT   $FSTAB_BOOT     vfat    defaults,ro       0       2
PARTUUID=$UUID_ROOT_A /               ext4    defaults,noatime,ro  0       1
PARTUUID=$UUID_DATA   /data           ext4    defaults,noatime,commit=600,nofail  0       2

# RAM диски для логов (поверх оверлея, чтобы не забивать персистентный слой мусором)
tmpfs   /tmp            tmpfs   defaults,noatime,mode=1777,size=200M 0 0
tmpfs   /var/log        tmpfs   defaults,noatime,mode=0755,size=100M 0 0
tmpfs   /var/tmp        tmpfs   defaults,noatime,mode=1777,size=50M  0 0

# Резерв
PARTUUID=$UUID_FACTORY /factory       ext4    defaults,ro,noauto,nofail       0       2
PARTUUID=$UUID_ROOT_B  /mnt/root_b    ext4    defaults,ro,noauto,nofail       0       2
EOF

# CMDLINE:
CMDLINE_FILE="/mnt/dst/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE_FILE" ]; then CMDLINE_FILE="/mnt/dst/boot/cmdline.txt"; fi

if [ -f "$CMDLINE_FILE" ]; then
    log_info "Updating kernel args..."
    ORIG_CMD=$(cat "$CMDLINE_FILE")
    CLEAN_CMD=$(echo "$ORIG_CMD" | sed -E 's/root=PARTUUID=[^ ]+//g' | sed -E 's/init=[^ ]+//g')

    # УБРАЛИ boot=overlay - это причина паники!
    # Добавили fastboot и ro
    NEW_CMD="console=serial0,115200 console=tty1 root=PARTUUID=$UUID_ROOT_A rootfstype=ext4 fsck.mode=skip noswap ro rootwait"
    echo "$NEW_CMD $CLEAN_CMD" > "$CMDLINE_FILE"
fi

# CONFIG.TXT:
CONFIG_TXT="/mnt/dst/boot/firmware/config.txt"
if [ ! -f "$CONFIG_TXT" ]; then CONFIG_TXT="/mnt/dst/boot/config.txt"; fi

log_info "Enabling Initramfs in $CONFIG_TXT..."
sed -i 's/^auto_initramfs=/#auto_initramfs=/' "$CONFIG_TXT"

if ! grep -q "initramfs initramfs8" "$CONFIG_TXT"; then
    echo "" >> "$CONFIG_TXT"
    echo "[all]" >> "$CONFIG_TXT"
    echo "initramfs initramfs8 followkernel" >> "$CONFIG_TXT"
fi

log_info "Boot configuration updated."
