#!/bin/sh
set -eu
BOOT=/boot; [ -d /boot/firmware ] && BOOT=/boot/firmware

if ! mountpoint -q "$BOOT"; then
  echo "boot-rw: $BOOT is not mounted" >&2
  exit 1
fi

# Только если реально ro
if findmnt -no OPTIONS "$BOOT" | grep -qE '(^|,)ro(,|$)'; then
  mount -o remount,rw "$BOOT"
fi
sync
