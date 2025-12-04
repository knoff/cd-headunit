#!/bin/sh
# мини-трамплин: пишет маркер и запускает 00_run.sh

# autodetect BOOT
BOOT="/boot"; [ -d /boot/firmware ] && BOOT="/boot/firmware"
LOG="$BOOT/firstrun-00-bootstrap.log"

# минимальный лог (без bash-фич)
{
  echo "[bootstrap] start: $(date -Iseconds)"
  echo "[bootstrap] BOOT=$BOOT"
  echo "[bootstrap] writing probe file"
} >>"$LOG" 2>&1

# явный маркер старта — чтобы увидеть хоть что-то даже при раннем падении
echo "started $(date -Iseconds)" > "$BOOT/first-boot/.probe-00-start" 2>/dev/null

# запускаем основной шаг (уже с bash и его логикой)
if [ -x "$BOOT/first-boot/00_run.sh" ]; then
  exec /bin/bash "$BOOT/first-boot/00_run.sh"
else
  echo "[bootstrap][FATAL] 00_run.sh not executable or missing" >>"$LOG" 2>&1
  echo "missing" > "$BOOT/first-boot/.probe-00-missing"
  exit 1
fi
