#!/usr/bin/env bash
set -euo pipefail

BOOT="/boot"; [ -d /boot/firmware ] && BOOT="/boot/firmware"
echo "start: partition & clone"

# параметры
DEV="/dev/mmcblk0"
P1="${DEV}p1"; P2="${DEV}p2"; P3="${DEV}p3"; P4="${DEV}p4"; P5="${DEV}p5"; P6="${DEV}p6"
TARGET_P2_GB=8; TARGET_P3_GB=8; TARGET_P5_GB=3

# проверки
for b in sfdisk rsync resize2fs partprobe partx udevadm blkid; do command -v "$b" >/dev/null || { echo "[FATAL] $b"; exit 1; }; done
ROOTSRC="$(findmnt -no SOURCE / || true)"
[[ "$ROOTSRC" == "$P2" || "$ROOTSRC" == *"mmcblk0p2"* ]] || { echo "[FATAL] root not p2"; exit 1; }

# helpers
sectors_per_mib=2048
gb_to_sectors(){ awk -v g="$1" 'BEGIN{printf "%.0f", g*1024*1024*1024/512}'; }
align_up(){ awk -v x="$1" -v a="$sectors_per_mib" 'BEGIN{print ( ( (x + a - 1) / a ) * a ) }'; }

# читать геометрию
JSON="$(sfdisk --json "$DEV")"
P2_START=$(echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/start/{print $3; exit}')
P2_SIZE=$( echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/size/{print $3; exit}')
DISK_SECTORS=$(cat "/sys/block/$(basename $DEV)/size")
P2_END=$((P2_START + P2_SIZE - 1))
echo "disk=$DISK_SECTORS p2=$P2_START+$P2_SIZE end=$P2_END"

P2_TARGET_SECTORS=$(gb_to_sectors "$TARGET_P2_GB")
P3_SIZE_SECTORS=$(gb_to_sectors "$TARGET_P3_GB")
P5_SIZE_SECTORS=$(gb_to_sectors "$TARGET_P5_GB")

# p2: только расширяем до 8G
if (( P2_SIZE > P2_TARGET_SECTORS )); then echo "[00][ERR] p2>8G, abort"; exit 1; fi
if (( P2_SIZE < P2_TARGET_SECTORS )); then
  printf "start=%s, size=%s, type=83\n" "$P2_START" "$P2_TARGET_SECTORS" | sfdisk --no-reread -N 2 "$DEV"
  partprobe "$DEV" || true; partx -u "$DEV" || true; udevadm settle || true
  resize2fs "$P2"
  JSON="$(sfdisk --json "$DEV")"
  P2_START=$(echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/start/{print $3; exit}')
  P2_SIZE=$( echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/size/{print $3; exit}')
  P2_END=$((P2_START + P2_SIZE - 1))
fi

# план
NEXT_START=$(align_up $((P2_END + 1)))
P3_START="$NEXT_START"; P3_END=$((P3_START + P3_SIZE_SECTORS - 1))
P4_EXT_START=$(align_up $((P3_END + 1))); P4_EXT_END=$((DISK_SECTORS - 1))
P5_START=$(align_up $((P4_EXT_START + sectors_per_mib))); P5_END=$((P5_START + P5_SIZE_SECTORS - 1))
P6_START=$(align_up $((P5_END + 1))) # размер не задаём

echo "plan: p3 ${P3_START}-${P3_END}; p4ext ${P4_EXT_START}-${P4_EXT_END}; p5 ${P5_START}-${P5_END}; p6 start=${P6_START}"

# создать p3/p4/p5/p6
lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$' || { echo "start=${P3_START}, size=$((P3_END-P3_START+1)), type=83" | sfdisk --no-reread -N 3 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p4$' || { echo "start=${P4_EXT_START}, size=$((P4_EXT_END-P4_EXT_START+1)), type=5"  | sfdisk --no-reread -N 4 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p5$' || { echo "start=${P5_START}, size=$((P5_END-P5_START+1)), type=83"        | sfdisk --no-reread -N 5 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p6$' || { echo "type=83"                                                           | sfdisk --no-reread -N 6 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }

sleep 2

# mkfs & labels (только если нет ФС)
[ -z "$(blkid -s TYPE -o value "$P3" 2>/dev/null)" ] && mkfs.ext4 -F -L rootfs_B "$P3"
[ -z "$(blkid -s TYPE -o value "$P5" 2>/dev/null)" ] && mkfs.ext4 -F -L factory  "$P5"
[ -z "$(blkid -s TYPE -o value "$P6" 2>/dev/null)" ] && mkfs.ext4 -F -L data     "$P6"

# rsync A->B (если ещё не делали)
if ! [ -e /mnt/rootB/etc/fstab ]; then
  mkdir -p /mnt/rootB
  mount "$P3" /mnt/rootB
  rsync -aHAX --delete --exclude={"/proc/*","/sys/*","/dev/*","/run/*","/tmp/*","/lost+found","/mnt/*","/media/*"} / /mnt/rootB
  umount /mnt/rootB
fi

# fstab (A и B) из шаблона
UUID_P1=$(blkid -s PARTUUID -o value "$P1")
UUID_P2=$(blkid -s PARTUUID -o value "$P2")
UUID_P3=$(blkid -s PARTUUID -o value "$P3")
UUID_P5=$(blkid -s PARTUUID -o value "$P5")
UUID_P6=$(blkid -s PARTUUID -o value "$P6")

# A (текущая система на p2)
install -D -m0644 "$BOOT/first-boot/fstab.template" /etc/fstab
sed -i \
 -e "s#__BOOT_PARTUUID__#${UUID_P1}#g" \
 -e "s#__ROOT_PARTUUID__#${UUID_P2}#g" \
 -e "s#__DATA_PARTUUID__#${UUID_P6}#g" \
 -e "s#__FACTORY_PARTUUID__#${UUID_P5}#g" \
 -e "s#__BOOT_MNT__#${BOOT}#g" \
 /etc/fstab

# B (клон на p3)
mount "$P3" /mnt/rootB
install -D -m0644 "$BOOT/first-boot/fstab.template" /mnt/rootB/etc/fstab
sed -i \
 -e "s#__BOOT_PARTUUID__#${UUID_P1}#g" \
 -e "s#__ROOT_PARTUUID__#${UUID_P3}#g" \
 -e "s#__DATA_PARTUUID__#${UUID_P6}#g" \
 -e "s#__FACTORY_PARTUUID__#${UUID_P5}#g" \
 -e "s#__BOOT_MNT__#${BOOT}#g" \
 /mnt/rootB/etc/fstab
umount /mnt/rootB

echo "done"
exit 0
