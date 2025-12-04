#!/usr/bin/env bash
# v2 — restore rootfs from /factory/rootfs_{A|B}.tar.zst
set -euo pipefail

# --- BOOT path autodetect ---
BOOT="/boot"
if [[ -d /boot/firmware ]]; then
  BOOT="/boot/firmware"
fi

CMDLINE="${BOOT}/cmdline.txt"
FIRSTBOOT_DIR="${BOOT}/first-boot"

SLOT="${1:-A}"
DEV="/dev/mmcblk0p2"
IMG="/factory/rootfs_A.tar.zst"
NAME="rootfs_A"
if [[ "$SLOT" == "B" ]]; then
  DEV="/dev/mmcblk0p3"
  IMG="/factory/rootfs_B.tar.zst"
  NAME="rootfs_B"
fi
[[ -r "$IMG" ]] || { echo "Factory image not found: $IMG"; exit 1; }
read -r -p "This will WIPE ${NAME} (${DEV}). Continue? [y/N] " ans
[[ "${ans:-}" =~ ^[yY]$ ]] || { echo "Aborted."; exit 1; }
mkdir -p /mnt/restore_target
mount "$DEV" /mnt/restore_target
find /mnt/restore_target -mindepth 1 -maxdepth 1 ! -name 'lost+found' -exec rm -rf {} +
echo "Restoring ${NAME} from ${IMG} ..."
zstd -dc "$IMG" | tar -xpf - -C /mnt/restore_target
sync
umount /mnt/restore_target
echo "Done. You may switch rootfs and reboot."
