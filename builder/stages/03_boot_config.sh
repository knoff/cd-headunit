#!/bin/bash
# STAGE 03: Boot Configuration (Fstab & Cmdline)

log_step "03_boot_config.sh - Configuring Bootloader"

# 1. Получаем новые UUID
log_info "Reading partition UUIDs..."
UUID_BOOT=$(blkid -s PARTUUID -o value "${LOOP_DST}p1")
UUID_ROOT_A=$(blkid -s PARTUUID -o value "${LOOP_DST}p5")
UUID_ROOT_B=$(blkid -s PARTUUID -o value "${LOOP_DST}p6")
UUID_FACTORY=$(blkid -s PARTUUID -o value "${LOOP_DST}p7")
UUID_DATA=$(blkid -s PARTUUID -o value "${LOOP_DST}p8")

log_info "Target Root A: $UUID_ROOT_A"

# 2. Генерируем /etc/fstab (RO Root + Optimized Data)
log_info "Writing /etc/fstab..."

FSTAB_BOOT="/boot/firmware"
if [ ! -d "/mnt/dst/boot/firmware" ]; then FSTAB_BOOT="/boot"; fi

cat > /mnt/dst/etc/fstab <<EOF
proc            /proc           proc    defaults          0       0
PARTUUID=$UUID_BOOT   $FSTAB_BOOT     vfat    defaults,ro       0       2

# --- SYSTEM (Read-Only) ---
# Монтируем корень в RO. Ошибки файловой системы игнорируем (они не могут возникнуть при RO)
PARTUUID=$UUID_ROOT_A /               ext4    defaults,noatime,ro  0       1

# --- PERSISTENT DATA (Read-Write) ---
# commit=600: Сбрасывать буфер записи на диск раз в 10 минут (бережет флешку)
# noatime: Не писать время последнего доступа к файлу
PARTUUID=$UUID_DATA   /data           ext4    defaults,noatime,commit=600,nofail  0       2

# --- VOLATILE (RAM) ---
# Все, что исчезнет после перезагрузки
tmpfs   /tmp            tmpfs   defaults,noatime,mode=1777,size=200M 0 0
tmpfs   /var/log        tmpfs   defaults,noatime,mode=0755,size=100M 0 0
tmpfs   /var/tmp        tmpfs   defaults,noatime,mode=1777,size=50M  0 0
tmpfs   /var/lib/dhcp   tmpfs   defaults,noatime,mode=0755           0 0
tmpfs   /var/lib/sudo   tmpfs   defaults,noatime,mode=0700           0 0

# --- SPARE PARTITIONS (Hidden/Backup) ---
PARTUUID=$UUID_FACTORY /factory       ext4    defaults,ro,noauto,nofail       0       2
PARTUUID=$UUID_ROOT_B  /mnt/root_b    ext4    defaults,ro,noauto,nofail       0       2
EOF

# 3. Настраиваем cmdline.txt
# Добавляем fastboot (без проверки ФС) и noswap
CMDLINE_FILE="/mnt/dst/boot/firmware/cmdline.txt"
if [ ! -f "$CMDLINE_FILE" ]; then CMDLINE_FILE="/mnt/dst/boot/cmdline.txt"; fi

if [ -f "$CMDLINE_FILE" ]; then
    log_info "Updating kernel args in $CMDLINE_FILE..."
    ORIG_CMD=$(cat "$CMDLINE_FILE")
    CLEAN_CMD=$(echo "$ORIG_CMD" | sed -E 's/root=PARTUUID=[^ ]+//g' | sed -E 's/init=[^ ]+//g' | sed -E 's/fsck.repair=[^ ]+//g')

    # fastboot: пропускает проверку fsck при загрузке (рискованно для RW, отлично для RO)
    # noswap: запрещает ядру использовать swap
    # ro: монтирует корень в RO сразу при старте ядра
    NEW_CMD="console=serial0,115200 console=tty1 root=PARTUUID=$UUID_ROOT_A rootfstype=ext4 fsck.mode=skip noswap ro rootwait"

    echo "$NEW_CMD $CLEAN_CMD" > "$CMDLINE_FILE"
else
    log_warn "cmdline.txt not found!"
fi

log_info "Boot configuration updated (RO Mode)."
