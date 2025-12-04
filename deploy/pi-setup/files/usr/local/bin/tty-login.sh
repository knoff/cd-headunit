#!/bin/bash
set -euo pipefail

# ---------- базовые настройки ----------
umask 022
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# Логи самого tty-login
LOG_DIR=/var/log/tty-login
LOG_FILE="$LOG_DIR/tty-login.log"
mkdir -p "$LOG_DIR"
: > "$LOG_FILE" || true
chown root:root "$LOG_FILE" 2>/dev/null || true
chmod 0644 "$LOG_FILE" 2>/dev/null || true

log() { local ts; ts="$(date -Iseconds)"; echo "[$ts] $*" | tee -a "$LOG_FILE" | logger -t tty-login; }

# Каталоги логов скриптов и статусов
SCRIPT_LOG_ROOT=/var/logs/boot-scripts           # tmpfs (летучие логи)
PERSIST_LOG_ROOT=/data/log/boot-scripts          # постоянные логи
STATE_ROOT=/data/boot-scripts/state              # маркеры выполнения
mkdir -p "$SCRIPT_LOG_ROOT" "$PERSIST_LOG_ROOT" "$STATE_ROOT"
chown -R root:root "$SCRIPT_LOG_ROOT" "$PERSIST_LOG_ROOT" "$STATE_ROOT" 2>/dev/null || true
chmod 0755 "$SCRIPT_LOG_ROOT" "$PERSIST_LOG_ROOT" "$STATE_ROOT" 2>/dev/null || true
export SCRIPT_LOG_ROOT

# --------- настройки транзакций ----------
# верхний предел RAM на транзакции (общий tmpfs для всех overlay upper/work)
TX_TMPFS_ROOT=/run/tx
TX_TMPFS_SIZE=512M           # при 4ГБ RAM это безопасно
TX_DEFAULT_MODE=ram          # ram | disk | none
# паттерны для «тяжёлых» скриптов (евристика)
TX_HEAVY_PATTERNS='docker|postgres|apt|install|setup'

# Определяем BOOT
BOOT="/boot"; [ -d /boot/firmware ] && BOOT="/boot/firmware"

# Найти параметры монтирования BOOT
boot_info() { findmnt -no SOURCE,TARGET,OPTIONS "$BOOT"; }

boot_remount_rw() {
  local src tgt opts
  read -r src tgt opts < <(boot_info)
  if mountpoint -q "$BOOT" && [[ ",$opts," == *",ro,"* ]]; then
    log "remount $BOOT -> rw"
    mount -o remount,rw "$BOOT"
    sync
  fi
}

boot_remount_ro() {
  local src tgt opts
  read -r src tgt opts < <(boot_info)
  if mountpoint -q "$BOOT" && [[ ",$opts," != *",ro,"* ]]; then
    log "remount $BOOT -> ro"
    sync
    mount -o remount,ro "$BOOT"
    sync
  fi
}

# Защита от параллельных запусков (несколько консолей)
LOCK=/run/tty-login.lock
exec {FD}<> "$LOCK"
flock -n "$FD" || { log "another instance is running; handing control to login"; exec /bin/login -f cdreborn; }

log "tty-login start on $(tty) (BOOT=$BOOT)"


# Общий tmpfs для транзакций (если нужно) — монтируем один раз
if ! mountpoint -q "$TX_TMPFS_ROOT"; then
  mkdir -p "$TX_TMPFS_ROOT"
  mount -t tmpfs -o "size=$TX_TMPFS_SIZE,noatime,mode=0755" tmpfs "$TX_TMPFS_ROOT" || true
fi

# Транзакционное выполнение одного скрипта: overlay поверх /data с upper в RAM
run_script_tx() {
  local s="$1" script_name script_base ts script_log persist_log rc
  chmod +x "$s" || true
  script_name="$(basename "$s")"
  script_base="${script_name%.sh}"
  ts="$(date +%Y%m%d-%H%M%S)"

  # Логи
  script_log="$SCRIPT_LOG_ROOT/${script_base}.log"
  persist_log="$PERSIST_LOG_ROOT/${ts}-${script_base}.log"

  echo -e "\033[0;32m>>> Executing ${script_name}\033[0m"
  log "exec $s -> log $script_log (persist $persist_log)"
  : > "$script_log"     || true; chmod 0644 "$script_log"     2>/dev/null || true
  : > "$persist_log"    || true; chmod 0644 "$persist_log"    2>/dev/null || true

  # Маркеры состояния
  : > "$STATE_ROOT/${script_base}.started"
  rm -f "$STATE_ROOT/${script_base}.ok" "$STATE_ROOT/${script_base}.failed" 2>/dev/null || true

  # Проверим, что /data смонтирован
  if ! mountpoint -q /data; then
    log "[error] /data is not mounted"; echo "no-data" > "$STATE_ROOT/${script_base}.failed"; return 32
  fi

  # Определим режим транзакции
  local tx_mode="$TX_DEFAULT_MODE"
  # 1) Явный режим: строка в заголовке скрипта '# TX_MODE=...'
  if head -n 5 "$s" | grep -qE '^#\s*TX_MODE=(ram|disk|none)\>' ; then
    tx_mode="$(head -n 5 "$s" | sed -n 's/^#\s*TX_MODE=\(ram\|disk\|none\).*/\1/p' | head -n1)"
  elif [ -f "${s}.txmode" ]; then
    tx_mode="$(tr -d ' \t\r\n' < "${s}.txmode" 2>/dev/null || echo "$TX_DEFAULT_MODE")"
  else
    # 2) Евристика по имени
    if echo "$script_base" | grep -qiE "$TX_HEAVY_PATTERNS"; then
      tx_mode="disk"
    else
      # 3) Оценка доступной памяти
      mem_avail_kb="$(awk '/MemAvailable:/ {print $2; exit}' /proc/meminfo)"
      # если меньше 1.5ГБ свободно — диск
      if [ "${mem_avail_kb:-0}" -lt $(( 1500 * 1024 )) ]; then
        tx_mode="disk"
      fi
    fi
  fi
  log "tx-mode for ${script_name}: ${tx_mode}"

  # Готовим overlay вокруг /data согласно режиму
  local upper work tx
  case "$tx_mode" in
    ram)
      upper="$(mktemp -d "$TX_TMPFS_ROOT/upper.XXXXXX")"
      work="$(mktemp -d "$TX_TMPFS_ROOT/work.XXXXXX")"
      tx="$(mktemp -d "$TX_TMPFS_ROOT/data.XXXXXX")"
      ;;
    disk)
      mkdir -p /data/.tx
      upper="$(mktemp -d /data/.tx/upper.XXXXXX)"
      work="$(mktemp -d /data/.tx/work.XXXXXX)"
      tx="$(mktemp -d /data/.tx/data.XXXXXX)"
      ;;
    none)
      upper=""; work=""; tx=""
      ;;
  esac

  if [ "$tx_mode" != "none" ]; then
    mount -t overlay overlay -o "lowerdir=/data,upperdir=$upper,workdir=$work" "$tx"
    # Логи — всегда на реальный /data (обход COW)
    mkdir -p /data/log/boot-scripts "$tx/log/boot-scripts"
    mount --bind /data/log/boot-scripts "$tx/log/boot-scripts"
  fi

  # Запуск скрипта в приватном mount-namespace, где /data подменён на overlay
  set +e
  if [ "$tx_mode" != "none" ]; then
    unshare -m -- bash -c '
      mount --make-rprivate /
      mount --rbind '"$tx"' /data
      /usr/bin/env -i BOOT_SCRIPT_LOG="'"$script_log"'" SCRIPT_LOG_ROOT="'"$SCRIPT_LOG_ROOT"'" PATH="'"$PATH"'" \
        bash "'"$s"'" "'"$script_log"'"
    ' 2>&1 | tee -a "$script_log" | tee -a "$persist_log" | logger -t "boot-script:${script_base}"
  else
    # Без overlay: исполняем прямо на /data, но логи и статусы ведём как обычно
    /usr/bin/env -i BOOT_SCRIPT_LOG="$script_log" SCRIPT_LOG_ROOT="$SCRIPT_LOG_ROOT" PATH="$PATH" \
      bash "$s" "$script_log" 2>&1 \
      | tee -a "$script_log" | tee -a "$persist_log" | logger -t "boot-script:${script_base}"
  fi
  rc=${PIPESTATUS[0]}
  set -e

  # Размонтируем транзакционный вид
  if [ "$tx_mode" != "none" ]; then
    umount -R "$tx" 2>/dev/null || true
  fi

  if [ $rc -eq 0 ]; then
    if [ "$tx_mode" = "ram" ] || [ "$tx_mode" = "disk" ]; then
      log "ok $s (tx-commit:${tx_mode})"
      rsync -aHAX --delete --exclude '/log/boot-scripts/**' "$tx"/ /data/
      sync
    else
      log "ok $s (no-tx, synced)"
      sync
    fi
    rm -f "$persist_log" 2>/dev/null || true
    # Локальный постоянный лог этого скрипта нам больше не нужен
    rm -f "$persist_log" 2>/dev/null || true
    : > "$STATE_ROOT/${script_base}.ok"
    rm -f "$STATE_ROOT/${script_base}.started" 2>/dev/null || true

    # Удаляем скрипт с BOOT только после успешного sync
    boot_remount_rw
    rm -f -- "$s" || log "[warn] failed to remove $s"
    sync
    boot_remount_ro
  else
    echo "rc=$rc" > "$STATE_ROOT/${script_base}.failed"
    rm -f "$STATE_ROOT/${script_base}.started" 2>/dev/null || true
    log "[error] ${s} failed (mode=${tx_mode}, rc=$rc). stopping queue."
  fi

  # Уборка времёнок overlay (upper/work/tx)
  [ -n "$tx" ]    && rm -rf "$tx"
  [ -n "$upper" ] && rm -rf "$upper"
  [ -n "$work" ]  && rm -rf "$work"

  return $rc
}

# Поиск и запуск скриптов на BOOT
SCRIPTS_DIR="$BOOT/scripts"
shopt -s nullglob

if [[ -d "$SCRIPTS_DIR" ]]; then
  scripts=( "$SCRIPTS_DIR"/*.sh )
  if (( ${#scripts[@]} )); then
    echo -e "\033[1;33mDeveloper auto mode: executing scripts from $SCRIPTS_DIR\033[0m"
    log "found ${#scripts[@]} script(s) on $BOOT"

    # Временный rw — будем удалять файлы после УСПЕШНЫХ коммитов
    boot_remount_rw

    # Выполняем по одному, транзакционно; при первой ошибке — стоп
    for s in "${scripts[@]}"; do
      if ! run_script_tx "$s"; then
        # Возвращаем BOOT в ro и выходим с кодом ошибки — очередь остановлена
        boot_remount_ro
        exit 1
      fi
    done

    # Попробуем убрать директорию, если пустая
    rmdir "$SCRIPTS_DIR" 2>/dev/null || log "[info] $SCRIPTS_DIR not removed (not empty?)"

    # Возвращаем ro и перезагружаемся
    boot_remount_ro
    log "scheduling reboot after scripts"
    (sleep 2; systemctl reboot) &
    exit 0
  fi
fi

# Скриптов нет — отдаём интерактив
echo -e "\033[0;32mNo scripts found - starting interactive shell\033[0m"
log "no scripts found - interactive mode"
exec /bin/login -f cdreborn
