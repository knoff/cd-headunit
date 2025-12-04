#!/bin/bash
set -euo pipefail

# ---------- базовые настройки ----------
umask 022
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

# Логирование самого tty-login: в файл и в journald
LOG_DIR=/var/log/tty-login
LOG_FILE="$LOG_DIR/tty-login.log"
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chown root:root "$LOG_FILE"
chmod 0644 "$LOG_FILE"

# Каталог логов для скриптов, запускаемых с BOOT
# (каждый скрипт пишет в /var/logs/boot-scripts/<scriptname>.log)
SCRIPT_LOG_ROOT=/var/logs/boot-scripts
mkdir -p "$SCRIPT_LOG_ROOT"
chown root:root "$SCRIPT_LOG_ROOT"
chmod 0755 "$SCRIPT_LOG_ROOT"

SCRIPT_LOG_ROOT=/var/logs/boot-scripts
mkdir -p "$SCRIPT_LOG_ROOT"; chown root:root "$SCRIPT_LOG_ROOT"; chmod 0755 "$SCRIPT_LOG_ROOT"
export SCRIPT_LOG_ROOT

log() {
  local ts; ts="$(date -Iseconds)"
  echo "[$ts] $*" | tee -a "$LOG_FILE" | logger -t tty-login
}

# Определяем BOOT
BOOT="/boot"
[ -d /boot/firmware ] && BOOT="/boot/firmware"

# Найдём устройство и текущие опции монтирования
boot_info() {
  # SOURCE,TARGET,OPTIONS
  findmnt -no SOURCE,TARGET,OPTIONS "$BOOT"
}

boot_remount_rw() {
  local src tgt opts
  read -r src tgt opts < <(boot_info)
  if mountpoint -q "$BOOT"; then
    if [[ ",$opts," == *",ro,"* ]]; then
      log "remount $BOOT -> rw"
      mount -o remount,rw "$BOOT"
      sync
    fi
  fi
}

boot_remount_ro() {
  local src tgt opts
  read -r src tgt opts < <(boot_info)
  if mountpoint -q "$BOOT"; then
    if [[ ",$opts," != *",ro,"* ]]; then
      log "remount $BOOT -> ro"
      sync
      mount -o remount,ro "$BOOT"
      sync
    fi
  fi
}

# Защита от параллельных запусков (несколько консолей)
LOCK=/run/tty-login.lock
exec {FD}<> "$LOCK"
flock -n "$FD" || { log "another instance is running; handing control to login"; exec /bin/login -f cdreborn; }

log "tty-login start on $(tty) (BOOT=$BOOT)"

# Нужная директория с скриптами?
SCRIPTS_DIR="$BOOT/scripts"
shopt -s nullglob

if [[ -d "$SCRIPTS_DIR" ]]; then
  # Проверим, есть ли там *.sh
  scripts=( "$SCRIPTS_DIR"/*.sh )
  if (( ${#scripts[@]} )); then
    echo -e "\033[1;33mDeveloper auto mode: executing scripts from $SCRIPTS_DIR\033[0m"
    log "found ${#scripts[@]} script(s) on $BOOT"

    # Временный rw для возможности удалять файлы по мере выполнения
    boot_remount_rw

    for s in "${scripts[@]}"; do
      chmod +x "$s" || true
      script_name="$(basename "$s")"
      script_base="${script_name%.sh}"
      script_log="$SCRIPT_LOG_ROOT/${script_base}.log"

      echo -e "\033[0;32m>>> Executing ${script_name}\033[0m"
      log "exec $s -> log $script_log"

      # Создаём файл лога для скрипта
      : > "$script_log" || true
      chown root:root "$script_log" 2>/dev/null || true
      chmod 0644 "$script_log" 2>/dev/null || true

      # Запускаем с «чистым» окружением, передаём BOOT_SCRIPT_LOG и путь лог-файла первым аргументом
      /usr/bin/env -i BOOT_SCRIPT_LOG="$script_log" PATH="$PATH" \
        bash "$s" "$script_log" 2>&1 \
        | tee -a "$script_log" \
        | logger -t "boot-script:${script_base}"

      log "done $s"
      # Удаляем скрипт сразу после выполнения
      rm -f -- "$s" || log "[warn] failed to remove $s"
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
