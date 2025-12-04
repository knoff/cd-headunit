#!/usr/bin/env bash
# v2 — A/B + DATA + FACTORY partitioning and cloning on first boot
# Triggers when /boot/firmware/first-boot.run exists. Creates p1..p5, clones current root to A & B,
# writes fstab/cmdline, installs helper scripts and systemd units, then reboots.
set -euo pipefail

# --- BOOT path autodetect ---
BOOT="/boot"
if [[ -d /boot/firmware ]]; then
  BOOT="/boot/firmware"
fi

CMDLINE="${BOOT}/cmdline.txt"
FIRSTBOOT_DIR="${BOOT}/first-boot"

# лог
LOG="${BOOT}/first-boot/clone.log"
exec > >(tee -a "$LOG") 2>&1

# ---- Defaults ----
DISK=${DISK:-/dev/mmcblk0}
BOOT_PART_SZ_MB=${BOOT_PART_SZ_MB:-512}
ROOT_PART_SZ_MB=${ROOT_PART_SZ_MB:-8192}
FACTORY_PART_SZ_MB=${FACTORY_PART_SZ_MB:-3072}
SECTORS_PER_MB=2048

BOOT_LABEL=${BOOT_LABEL:-boot}
ROOTA_LABEL=${ROOTA_LABEL:-rootfs_A}
ROOTB_LABEL=${ROOTB_LABEL:-rootfs_B}
DATA_LABEL=${DATA_LABEL:-data}
FACTORY_LABEL=${FACTORY_LABEL:-factory}

TRIGGER="$BOOT/first-boot.run"
MARKER="$BOOT/first-boot.done"

log(){ echo "[first-boot] $*"; }

# [[ -f "$TRIGGER" ]] || exit 0

if lsblk | grep -q 'mmcblk0p5 .* factory'; then
  echo "[first-boot] Разметка уже выполнена, выхожу."; exit 0
fi

if [[ -f "$MARKER" ]]; then log "Already initialized"; exit 0; fi

ROOTDEV=$(findmnt -no SOURCE / || true)
if [[ "$ROOTDEV" =~ mmcblk0p2 ]]; then
  echo "[first-boot] Root сейчас на ${ROOTDEV}. Останавливаюсь, переразметка живого root опасна."
  exit 1
fi

swapoff -a || true
systemctl stop docker 2>/dev/null || true

log "Partitioning ${DISK}..."
BOOT_SZ=$((BOOT_PART_SZ_MB*SECTORS_PER_MB))
ROOT_SZ=$((ROOT_PART_SZ_MB*SECTORS_PER_MB))
FACTORY_SZ=$((FACTORY_PART_SZ_MB*SECTORS_PER_MB))

# Initial p1..p4, with p4 as "rest of disk"
sfdisk "${DISK}" <<EOF
label: dos
unit: sectors
${DISK}p1 : start=2048, size=${BOOT_SZ}, type=c
${DISK}p2 : size=${ROOT_SZ}, type=83
${DISK}p3 : size=${ROOT_SZ}, type=83
${DISK}p4 : type=83
EOF

partprobe "${DISK}" || true; sleep 2

# Shrink p4 to make room for p5 (factory) at the end
eval $(sfdisk -d "${DISK}" | awk '$1 ~ /p4/ {print "P4_START="$4"; P4_SIZE="$6}')
NEW_P4_SIZE=$((P4_SIZE - FACTORY_SZ))
P5_START=$((P4_START + NEW_P4_SIZE))
if (( NEW_P4_SIZE <= 0 )); then log "Not enough space for factory partition"; exit 1; fi

sfdisk --no-reread "${DISK}" <<EOF
label: dos
unit: sectors
${DISK}p1 : start=2048, size=${BOOT_SZ}, type=c
${DISK}p2 : size=${ROOT_SZ}, type=83
${DISK}p3 : size=${ROOT_SZ}, type=83
${DISK}p4 : start=${P4_START}, size=${NEW_P4_SIZE}, type=83
${DISK}p5 : start=${P5_START}, size=${FACTORY_SZ}, type=83
EOF

partprobe "${DISK}" || true; sleep 2

# Format
mkfs.vfat -F32 -n "${BOOT_LABEL}"   ${DISK}p1
mkfs.ext4 -F -L "${ROOTA_LABEL}"    ${DISK}p2
mkfs.ext4 -F -L "${ROOTB_LABEL}"    ${DISK}p3
mkfs.ext4 -F -L "${DATA_LABEL}"     ${DISK}p4
mkfs.ext4 -F -L "${FACTORY_LABEL}"  ${DISK}p5

# Mount
mkdir -p /mnt/newrootA /mnt/newrootB /mnt/data
mount ${DISK}p2 /mnt/newrootA
mount ${DISK}p3 /mnt/newrootB
mount ${DISK}p4 /mnt/data
mountpoint -q ${BOOT} || mount ${DISK}p1 ${BOOT}

# Clone current root into A and B
log "Cloning current root → A"
rsync -aHAX --numeric-ids --delete \
  --exclude={"${BOOT}/*","/dev/*","/proc/*","/sys/*","/mnt/*","/run/*","/tmp/*","/lost+found"} \
  / /mnt/newrootA/

log "Cloning current root → B"
rsync -aHAX --numeric-ids --delete \
  --exclude={"${BOOT}/*","/dev/*","/proc/*","/sys/*","/mnt/*","/run/*","/tmp/*","/lost+found"} \
  / /mnt/newrootB/

# PARTUUIDs
PARTUUID_P1=$(blkid -s PARTUUID -o value ${DISK}p1)
PARTUUID_A=$(blkid -s PARTUUID -o value ${DISK}p2)
PARTUUID_B=$(blkid -s PARTUUID -o value ${DISK}p3)
PARTUUID_DATA=$(blkid -s PARTUUID -o value ${DISK}p4)
PARTUUID_FACTORY=$(blkid -s PARTUUID -o value ${DISK}p5)

# cmdline → root=A
if [[ -f ${CMDLINE} ]]; then
  sed -E "s#root=PARTUUID=[a-f0-9-]+#root=PARTUUID=${PARTUUID_A}#" -i ${CMDLINE}
fi

# fstab in A and B
install -D -m 0644 ${FIRSTBOOT_DIR}/fstab.template /mnt/newrootA/etc/fstab
install -D -m 0644 ${FIRSTBOOT_DIR}/fstab.template /mnt/newrootB/etc/fstab
for SLOT in A B; do
  ROOTUUID=$([ "$SLOT" = A ] && echo "${PARTUUID_A}" || echo "${PARTUUID_B}")
  sed -i \
    -e "s#__BOOT_PARTUUID__#${PARTUUID_P1}#" \
    -e "s#__ROOT_PARTUUID__#${ROOTUUID}#" \
    -e "s#__DATA_PARTUUID__#${PARTUUID_DATA}#" \
    -e "s#__FACTORY_PARTUUID__#${PARTUUID_FACTORY}#" \
    -e "s#__BOOT_MNT__#${BOOT}#" \
    /mnt/newroot${SLOT}/etc/fstab
done

# Install helper scripts
install -D -m 0755 ${FIRSTBOOT_DIR}/switch_rootfs.sh      /mnt/newrootA/usr/local/sbin/switch_rootfs.sh
install -D -m 0755 ${FIRSTBOOT_DIR}/switch_rootfs.sh      /mnt/newrootB/usr/local/sbin/switch_rootfs.sh
install -D -m 0755 ${FIRSTBOOT_DIR}/restore_factory.sh    /mnt/newrootA/usr/local/sbin/restore_factory.sh
install -D -m 0755 ${FIRSTBOOT_DIR}/restore_factory.sh    /mnt/newrootB/usr/local/sbin/restore_factory.sh
install -D -m 0644 ${FIRSTBOOT_DIR}/relocate-data-bind.mounts /mnt/newrootA/etc/systemd/system/relocate-data-bind.mounts
install -D -m 0644 ${FIRSTBOOT_DIR}/relocate-data-bind.mounts /mnt/newrootB/etc/systemd/system/relocate-data-bind.mounts

# Device init (network, users, hostname from /boot/device.conf)
install -D -m 0755 ${FIRSTBOOT_DIR}/init-device-config.sh /mnt/newrootA/usr/local/sbin/init-device-config.sh
install -D -m 0755 ${FIRSTBOOT_DIR}/init-device-config.sh /mnt/newrootB/usr/local/sbin/init-device-config.sh
install -D -m 0644 ${FIRSTBOOT_DIR}/device-init.service   /mnt/newrootA/etc/systemd/system/device-init.service
install -D -m 0644 ${FIRSTBOOT_DIR}/device-init.service   /mnt/newrootB/etc/systemd/system/device-init.service

chroot /mnt/newrootA /bin/bash -c "systemctl enable relocate-data-bind.mounts device-init.service || true"
chroot /mnt/newrootB /bin/bash -c "systemctl enable relocate-data-bind.mounts device-init.service || true"

# Mark done
touch "$MARKER"; rm -f "$TRIGGER"; sync
log "Rebooting to rootfs_A..."
reboot
