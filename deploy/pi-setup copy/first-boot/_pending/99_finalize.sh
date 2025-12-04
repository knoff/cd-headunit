#!/usr/bin/env bash
set -euo pipefail
BOOT="/boot"; [ -d /boot/firmware ] && BOOT="/boot/firmware"
echo "start: finalize & cleanup"

# убрать секреты/утилиты при желании:
rm -f "$BOOT/device.conf" "$BOOT/imager_custom" "$BOOT/userconf" 2>/dev/null || true

# финал: убрать systemd.run (ничего больше не запускать)
echo "final: clear systemd.run"
set_next ""   # <- удаляет все systemd.run* из cmdline, reboot больше НЕ будет

sync
echo "finished"
exit 0
