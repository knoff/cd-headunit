#!/usr/bin/env bash
set -euo pipefail

# ================== autodetect BOOT & logging ==================
BOOT="/boot"; [[ -d /boot/firmware ]] && BOOT="/boot/firmware"
LOG="${BOOT}/first-boot/clone.log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
echo "[clone] start"

DONE_FLAG="${BOOT}/first-boot/.clone_done"
if [ -f "$DONE_FLAG" ]; then
  echo "[clone] already done, exiting"
  exit 0
fi

# ================== consts ==================
DEV="/dev/mmcblk0"
P1="${DEV}p1"; P2="${DEV}p2"; P3="${DEV}p3"; P4="${DEV}p4"; P5="${DEV}p5"; P6="${DEV}p6"
TARGET_P2_GB=8    # /
TARGET_P3_GB=8    # rootfs_B
TARGET_P5_GB=3    # factory (ro)

# ================== GUARD-0: prerequisites ==================
[[ $EUID -eq 0 ]] || { echo "[clone][FATAL] run as root"; exit 1; }
for bin in sfdisk rsync resize2fs partprobe udevadm blkid; do
  command -v "$bin" >/dev/null || { echo "[clone][FATAL] missing binary: $bin"; exit 1; }
done

# ================== GUARD-1: boot (p1) must exist ==================
if ! lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p1$'; then
  echo "[clone][FATAL] p1 (boot) not found; abort"; exit 1
fi

# ================== GUARD-2: idempotency (if p3 exists -> done) ==================
if lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$'; then
  echo "[clone] p3 exists -> skipping (already partitioned)"; exit 0
fi

# ================== GUARD-3: root must be on p2 (we only expand) ==================
ROOTSRC="$(findmnt -no SOURCE / || true)"
if [[ "$ROOTSRC" != "$P2" && "$ROOTSRC" != *"mmcblk0p2"* ]]; then
  echo "[clone][FATAL] unexpected root device: $ROOTSRC"; exit 1
fi

# ================== geometry helpers ==================
sectors_per_mib=2048        # 1MiB alignment (512-byte sectors)
gb_to_sectors() { awk -v g="$1" 'BEGIN{printf "%.0f", g*1024*1024*1024/512}'; }
align_up()   { awk -v x="$1" -v a="$sectors_per_mib" 'BEGIN{print ( ( (x + a - 1) / a ) * a ) }'; }
get_size_sectors() { cat "/sys/block/$(basename $DEV)/size"; } # whole disk

# read current table
JSON="$(sfdisk --json "$DEV")"
P2_START=$(echo "$JSON" | awk -F'[:, ]+' '/"node": "\/dev\/mmcblk0p2"/{f=1} f&&/"start"/{print $3; exit}')
P2_SIZE=$( echo "$JSON" | awk -F'[:, ]+' '/"node": "\/dev\/mmcblk0p2"/{f=1} f&&/"size"/{print $3; exit}')
[[ -n "$P2_START" && -n "$P2_SIZE" ]] || { echo "[clone][FATAL] cannot parse p2 from sfdisk json"; exit 1; }
P2_END=$((P2_START + P2_SIZE - 1))

DISK_SECTORS=$(get_size_sectors)
[[ -n "$DISK_SECTORS" ]] || { echo "[clone][FATAL] cannot read disk size"; exit 1; }

# desired sizes in sectors
P2_TARGET_SECTORS=$(gb_to_sectors "$TARGET_P2_GB")
P3_SIZE_SECTORS=$(gb_to_sectors "$TARGET_P3_GB")
P5_SIZE_SECTORS=$(gb_to_sectors "$TARGET_P5_GB")

echo "[clone] disk sectors: $DISK_SECTORS"
echo "[clone] p2 start=$P2_START size=$P2_SIZE end=$P2_END"
echo "[clone] targets: p2=${TARGET_P2_GB}G p3=${TARGET_P3_GB}G p5=${TARGET_P5_GB}G"

# ================== GUARD-4: never shrink p2 ==================
if (( P2_SIZE > P2_TARGET_SECTORS )); then
  echo "[clone][ERROR] p2 > ${TARGET_P2_GB}G (size=${P2_SIZE} sectors). Cannot shrink online. Abort."
  exit 1
fi

# expand p2 to exactly 8G if smaller
if (( P2_SIZE < P2_TARGET_SECTORS )); then
  NEW_P2_END=$((P2_START + P2_TARGET_SECTORS - 1))
  echo "[clone] expanding p2 to ${TARGET_P2_GB}G (end=$NEW_P2_END)"
  printf "start=%s, size=%s, type=83\n" "$P2_START" "$P2_TARGET_SECTORS" | sfdisk --no-reread -N 2 "$DEV"
  partprobe "$DEV" || true; partx -u "$DEV" || true; udevadm settle || true
  echo "[clone] resize2fs $P2"
  resize2fs "$P2"
  # refresh numbers
  JSON="$(sfdisk --json "$DEV")"
  P2_START=$(echo "$JSON" | awk -F'[:, ]+' '/"node": "\/dev\/mmcblk0p2"/{f=1} f&&/"start"/{print $3; exit}')
  P2_SIZE=$( echo "$JSON" | awk -F'[:, ]+' '/"node": "\/dev\/mmcblk0p2"/{f=1} f&&/"size"/{print $3; exit}')
  P2_END=$((P2_START + P2_SIZE - 1))
fi

# ================== compute new partitions layout ==================
NEXT_START=$((P2_END + 1))
NEXT_START=$(align_up "$NEXT_START")

# p3
P3_START="$NEXT_START"
P3_END=$((P3_START + P3_SIZE_SECTORS - 1))

# p4 будет extended и займёт ВСЁ оставшееся до конца диска
P4_EXT_START=$((P3_END + 1)); P4_EXT_START=$(align_up "$P4_EXT_START")
P4_EXT_END=$((DISK_SECTORS - 1))

# внутри extended:
# p5 (factory, 3G)
P5_START=$((P4_EXT_START + sectors_per_mib)); P5_START=$(align_up "$P5_START")
P5_END=$((P5_START + P5_SIZE_SECTORS - 1))
#p6 (data) - без фиксированного size, пусть занимает остаток extended
P6_START=$((P5_END + 1)); P6_START=$(align_up "$P6_START")
#P6_END=$((P4_EXT_END))  # до конца extended

echo "[clone] plan:"
printf "  p3: %s-%s (8G)\n" "$P3_START" "$P3_END"
printf "  p4(ext): %s-%s (container)\n" "$P4_EXT_START" "$P4_EXT_END"
printf "  p5(factory): %s-%s (3G)\n" "$P5_START" "$P5_END"
printf "  p6(data): start=%s (to end of extended)\n" "$P6_START"

# ================== create p3, p5, p4 safely (one-by-one) ==================
# GUARD-5: ensure numbers are free
for N in 3 4 5 6; do
  if lsblk -nr -o NAME "$DEV" | grep -q "^mmcblk0p${N}\$"; then
    echo "[clone][FATAL] p${N} already exists unexpectedly; abort"; exit 1
  fi
done

# p3
if ! lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$'; then
  echo "start=${P3_START}, size=$((P3_END-P3_START+1)), type=83" | sfdisk --no-reread -N 3 "$DEV"
  partprobe "$DEV" || true; partx -u "$DEV" || true; udevadm settle || true
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$' || { echo "[clone][FATAL] p3 not present after sfdisk"; exit 1; }
fi

# p4 extended
if ! lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p4$'; then
  echo "start=${P4_EXT_START}, size=$((P4_EXT_END-P4_EXT_START+1)), type=5" | sfdisk --no-reread -N 4 "$DEV"
  partprobe "$DEV" || true; partx -u "$DEV" || true; udevadm settle || true
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p4$' || { echo "[clone][FATAL] p4(ext) not present"; exit 1; }
fi

# p5 (logical) — factory
if ! lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p5$'; then
  echo "start=${P5_START}, size=$((P5_END-P5_START+1)), type=83" | sfdisk --no-reread -N 5 "$DEV"
  partprobe "$DEV" || true; partx -u "$DEV" || true; udevadm settle || true
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p5$' || { echo "[clone][FATAL] p5 not present"; exit 1; }
fi

# p6 logical (data, всё остальное внутри extended) — БЕЗ start/size
if ! lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p6$'; then
  echo "type=83" | sfdisk --no-reread -N 6 "$DEV"
  partprobe "$DEV" || true; partx -u "$DEV" || true; udevadm settle || true
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p6$' || { echo "[clone][FATAL] p6 not present"; exit 1; }
fi

sleep 5

# ================== mkfs & labels ==================
mkfs.ext4 -F -L rootfs_B "$P3"
mkfs.ext4 -F -L factory  "$P5"
mkfs.ext4 -F -L data     "$P6"

# ================== clone A -> B ==================
mkdir -p /mnt/rootB
mount "$P3" /mnt/rootB
rsync -aHAX --delete \
  --exclude={"/proc/*","/sys/*","/dev/*","/run/*","/tmp/*","/lost+found","/mnt/*","/media/*"} \
  / /mnt/rootB
umount /mnt/rootB

# ================== fstab for A & B ==================
FIRSTBOOT_DIR="${BOOT}/first-boot"
install -D -m0644 "${FIRSTBOOT_DIR}/fstab.template" /etc/fstab
install -D -m0644 "${FIRSTBOOT_DIR}/fstab.template" /mnt/rootB/etc/fstab

BOOT_MNT="$BOOT"

UUID_P1=$(blkid -s PARTUUID -o value "$P1")
UUID_P2=$(blkid -s PARTUUID -o value "$P2")
UUID_P3=$(blkid -s PARTUUID -o value "$P3")
UUID_P5=$(blkid -s PARTUUID -o value "$P5")
UUID_P6=$(blkid -s PARTUUID -o value "$P6")

# A (rootfs_A)
sed -i \
 -e "s#__BOOT_PARTUUID__#${UUID_P1}#g" \
 -e "s#__ROOT_PARTUUID__#${UUID_P2}#g" \
 -e "s#__DATA_PARTUUID__#${UUID_P6}#g" \
 -e "s#__FACTORY_PARTUUID__#${UUID_P5}#g" \
 -e "s#__BOOT_MNT__#${BOOT}#g" \
 /etc/fstab

# B (rootfs_B)
mount "$P3" /mnt/rootB
sed -i \
 -e "s#__BOOT_PARTUUID__#${UUID_P1}#g" \
 -e "s#__ROOT_PARTUUID__#${UUID_P3}#g" \
 -e "s#__DATA_PARTUUID__#${UUID_P6}#g" \
 -e "s#__FACTORY_PARTUUID__#${UUID_P5}#g" \
 -e "s#__BOOT_MNT__#${BOOT}#g" \
 /mnt/rootB/etc/fstab
umount /mnt/rootB

# ================== done ==================
touch "$DONE_FLAG"
echo "[clone] done; requesting single reboot"
sleep 1
reboot
