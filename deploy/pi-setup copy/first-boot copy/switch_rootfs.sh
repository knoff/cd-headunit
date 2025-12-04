#!/usr/bin/env bash
# v2 — switch rootfs A <-> B by editing /boot/firmware/cmdline.txt
set -euo pipefail
# --- BOOT path autodetect ---
BOOT="/boot"
if [[ -d /boot/firmware ]]; then
  BOOT="/boot/firmware"
fi

CMDLINE="${BOOT}/cmdline.txt"
FIRSTBOOT_DIR="${BOOT}/first-boot"

[[ -d "$BOOT" ]] || { echo "boot not mounted"; exit 1; }
A_UUID=$(blkid -s PARTUUID -o value /dev/mmcblk0p2 || true)
B_UUID=$(blkid -s PARTUUID -o value /dev/mmcblk0p3 || true)
CUR=$(cat "$BOOT/cmdline.txt")
if grep -q "${A_UUID}" <<< "$CUR"; then
  sed -E "s#root=PARTUUID=[a-f0-9-]+#root=PARTUUID=${B_UUID}#" -i "$CMDLINE"
  echo "Switching A → B. Reboot to apply."
elif grep -q "${B_UUID}" <<< "$CUR"; then
  sed -E "s#root=PARTUUID=[a-f0-9-]+#root=PARTUUID=${A_UUID}#" -i "$CMDLINE"
  echo "Switching B → A. Reboot to apply."
else
  echo "Unknown current root in cmdline.txt"; exit 2
fi
sync
