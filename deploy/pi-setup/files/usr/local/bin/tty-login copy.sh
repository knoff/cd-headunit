#!/bin/bash
set -euo pipefail

BOOT="/boot"
[ -d /boot/firmware ] && BOOT="/boot/firmware"

LOG="$BOOT/tty-login.log"
echo "[$(date -Iseconds)] tty-login start on $(tty)" >> "$LOG"

# Цветовые коды
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # no color

# Проверка наличия скриптов
if [ -d "$BOOT/scripts" ] && ls "$BOOT/scripts/"*.sh >/dev/null 2>&1; then
  echo -e "${YELLOW}Developer auto mode: executing scripts from $BOOT/scripts${NC}" | tee -a "$LOG"

  for s in "$BOOT/scripts/"*.sh; do
    [ -x "$s" ] || chmod +x "$s"
    echo -e "${GREEN}>>> Executing $(basename "$s")${NC}" | tee -a "$LOG"
    echo "[$(date -Iseconds)] exec $s" >> "$LOG"
    bash "$s" | tee -a "$LOG"
    echo "[$(date -Iseconds)] done $s" >> "$LOG"
    # Удаляем скрипт сразу после выполнения
    rm -f "$s" || echo "[warn] failed to remove $s" >> "$LOG"
  done

  # После выполнения всех — удаляем папку, если пуста
  rmdir "$BOOT/scripts" 2>/dev/null || echo "[info] directory $BOOT/scripts not removed (not empty?)" >> "$LOG"

  echo "[$(date -Iseconds)] scheduling reboot" >> "$LOG"
  sync
  (sleep 2; systemctl reboot) &
  exit 0
fi

# Если скриптов нет — интерактивный режим
echo -e "${GREEN}No scripts found — starting interactive shell${NC}" | tee -a "$LOG"
echo "[$(date -Iseconds)] no scripts found — interactive mode" >> "$LOG"
exec /bin/login -f cdreborn
