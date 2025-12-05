#!/bin/bash
# STAGE 03: Boot Configuration (Fstab & Cmdline)

log_step "03_boot_config.sh - Configuring Bootloader"

# 1. Получаем новые UUID
# Нам нужны PARTUUID, так как они уникальны для таблицы разделов
log_info "Reading partition UUIDs..."

UUID_BOOT=$(blkid -s PARTUUID -o value "${LOOP_DST}p1")
UUID_ROOT_A=$(blkid -s PARTUUID -o value "${LOOP_DST}p5")
UUID_ROOT_B=$(blkid -s PARTUUID -o value "${LOOP_DST}p6")
UUID_FACTORY=$(blkid -s PARTUUID -o value "${LOOP_DST}p7")
UUID_DATA=$(blkid -s PARTUUID -o value "${LOOP_DST}p8")

log_info "Target Root A: $UUID_ROOT_A"

# 2. Генерируем /etc/fstab
log_info "Writing /etc/fstab..."

# Определяем точку монтирования boot для fstab (обычно /boot/firmware для Debian 12+)
# Но так как мы пишем в файл внутри образа, путь должен быть абсолютным внутри образа
FSTAB_BOOT="/boot/firmware"
if [ ! -d "/mnt/dst/boot/firmware" ]; then
    FSTAB_BOOT="/boot"
fi

cat > /mnt/dst/etc/fstab <<EOF
proc            /proc           proc    defaults          0       0
PARTUUID=$UUID_BOOT   $FSTAB_BOOT     vfat    defaults          0       2
PARTUUID=$UUID_ROOT_A /               ext4    defaults,noatime  0       1
# Data и Factory с флагом nofail (система загрузится, даже если они повреждены)
PARTUUID=$UUID_DATA   /data           ext4    defaults,noatime,nofail  0       2
PARTUUID=$UUID_FACTORY /factory       ext4    defaults,ro,nofail       0       2
# Root B монтируем только по требованию (noauto)
PARTUUID=$UUID_ROOT_B  /mnt/root_b    ext4    defaults,noauto,nofail   0       2

tmpfs   /tmp    tmpfs   defaults,noatime,mode=1777 0 0
tmpfs   /var/log tmpfs  defaults,noatime,mode=0755 0 0
EOF

# 3. Настраиваем cmdline.txt
# Пытаемся найти файл по двум путям
CMDLINE_FILE="/mnt/dst/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE_FILE" ]; then
    CMDLINE_FILE="/mnt/dst/boot/cmdline.txt"
fi

if [ -f "$CMDLINE_FILE" ]; then
    log_info "Updating kernel args in $CMDLINE_FILE..."

    ORIG_CMD=$(cat "$CMDLINE_FILE")
    # Вычищаем старые привязки (root=..., init=...) и "тихий" режим, чтобы видеть логи при загрузке
    CLEAN_CMD=$(echo "$ORIG_CMD" | sed -E 's/root=PARTUUID=[^ ]+//g' | sed -E 's/init=[^ ]+//g')

    # Собираем новую строку.
    # fsck.repair=yes — важно для headless систем, чтобы не висело на Press Enter при сбоях
    NEW_CMD="console=serial0,115200 console=tty1 root=PARTUUID=$UUID_ROOT_A rootfstype=ext4 fsck.repair=yes rootwait"

    echo "$NEW_CMD $CLEAN_CMD" > "$CMDLINE_FILE"
else
    log_warn "cmdline.txt not found! System might not boot."
fi

log_info "Boot configuration updated."
