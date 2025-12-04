#!/bin/sh
set -eu
BOOT=/boot; [ -d /boot/firmware ] && BOOT=/boot/firmware

if ! mountpoint -q "$BOOT"; then
  echo "boot-ro: $BOOT is not mounted" >&2
  exit 1
fi

# Только если не ro
if ! findmnt -no OPTIONS "$BOOT" | grep -qE '(^|,)ro(,|$)'; then
  sync
  mount -o remount,ro "$BOOT"
  sync
fi
