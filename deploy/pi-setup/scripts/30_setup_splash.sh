#!/bin/bash
set -euo pipefail

BOOT="/boot"
[ -d /boot/firmware ] && BOOT="/boot/firmware"

LOG_FILE="${BOOT_SCRIPT_LOG:-${1:-/dev/null}}"
log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" | logger -t "$(basename "$0")"; }

log "splash setup start"

# Устанавливаем необходимые пакеты
apt update
apt install -y plymouth plymouth-themes

# Устанавливаем тему
plymouth-set-default-theme spinner

# Правим параметры загрузки
CMDLINE="$BOOT/cmdline.txt"
sed -i 's| quiet splash||g' "$CMDLINE"
# Добавляем параметры для тишины загрузки и plymouth
sed -i 's|$| quiet splash logo.nologo vt.global_cursor_default=0 plymouth.ignore-serial-consoles|' "$CMDLINE"

# Обновляем initramfs
update-initramfs -u || echo "[warn] update-initramfs failed"

log "splash setup done"
