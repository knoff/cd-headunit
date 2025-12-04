#!/bin/sh
# fb_next: move current firstrun -> completed, install next pending NN_run.sh (or 99_finalize)
fb_boot() { BOOT="/boot"; [ -d /boot/firmware ] && BOOT="/boot/firmware"; echo "$BOOT"; }
fb_log()  { echo "[next] $*" >>"$(fb_boot)"/logs/firstrun-next.log; }

fb_next() {
  BOOT="$(fb_boot)"
  PENDING="$BOOT/first-boot/pending"
  DONE="$BOOT/first-boot/completed"

  mkdir -p "$DONE"
  TS="$(date -Iseconds 2>/dev/null | tr ':' '-')"
  [ -f "$BOOT/firstrun.sh" ] && mv -f "$BOOT/firstrun.sh" "$DONE/firstrun_$TS.sh"

  # выбрать следующий NN_run.sh (минимальный номер)
  NEXT="$(ls "$PENDING"/*_run.sh 2>/dev/null | sort | head -n1)"
  if [ -n "$NEXT" ] && [ -f "$NEXT" ]; then
    # нормализуем LF и shebang, копируя в firstrun.sh
    awk 'BEGIN{print "#!/usr/bin/env bash"} NR>1{gsub("\r$",""); print}' "$NEXT" > "$BOOT/firstrun.sh"
    chmod +x "$BOOT/firstrun.sh"
    mv -f "$NEXT" "$DONE/$(basename "$NEXT")"
    fb_log "installed $(basename "$BOOT/firstrun.sh") from $(basename "$NEXT")"
  else
    # шагов больше нет → установить финализатор
    SRC="$BOOT/first-boot/pending/99_finalize.sh"
    awk 'BEGIN{print "#!/usr/bin/env bash"} NR>1{gsub("\r$",""); print}' "$SRC" > "$BOOT/firstrun.sh"
    chmod +x "$BOOT/firstrun.sh"
    fb_log "installed 99_finalize.sh"
  fi
  sync
}
