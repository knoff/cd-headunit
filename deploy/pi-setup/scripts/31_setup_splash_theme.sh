#!/bin/bash
set -euo pipefail

BOOT="/boot"
[ -d /boot/firmware ] && BOOT="/boot/firmware"

LOG_FILE="${BOOT_SCRIPT_LOG:-${1:-/dev/null}}"
log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" | logger -t "$(basename "$0")"; }

log "splash theme for coffeedigital start"


# 1. Добавляем disable_splash в config.txt
CFG="$BOOT/config.txt"
if ! grep -q '^disable_splash=' "$CFG"; then
  echo 'disable_splash=1' >> "$CFG"
  log "added disable_splash=1 to config.txt"
else
  log "disable_splash already present"
fi

# 2. Убеждаемся, что параметры загрузки установлены в cmdline.txt
CMD="$BOOT/cmdline.txt"
# Убираем возможные дубли линий (не строгая проверка)
sed -i 's/ logo\.nologo//g' "$CMD"
sed -i 's/ splash//g' "$CMD"
sed -i 's/ vt\.global_cursor_default=[0-9]*//g' "$CMD"
sed -i 's/ plymouth\.ignore-serial-consoles//g' "$CMD"

# Добавляем нужные параметры, если ещё нет
if ! grep -q 'quiet splash logo.nologo vt.global_cursor_default=0 plymouth.ignore-serial-consoles' "$CMD"; then
  sed -i "s/$/ quiet splash logo.nologo vt.global_cursor_default=0 plymouth.ignore-serial-consoles/" "$CMD"
  log "appended splash parameters to cmdline.txt"
else
  log "splash parameters already in cmdline.txt"
fi

# 3. Подготовка темы: копирование/установка тема coffeedigital
# Копируем тему coffeedigital
THEME_DIR="/usr/share/plymouth/themes/coffeedigital"
THEME_SRC="$BOOT/files/themes/coffeedigital"
THEME_DST="/usr/share/plymouth/themes/coffeedigital"

mkdir -p "$THEME_DST"
cp -r "${THEME_SRC}/"* "$THEME_DST"
chmod -R 755 "$THEME_DST"
log "copied theme files to $THEME_DST"

# Обновляем альтернативу и устанавливаем тему
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$THEME_DST/coffeedigital.plymouth" 100 || true
update-alternatives --set default.plymouth "$THEME_DST/coffeedigital.plymouth" || true
plymouth-set-default-theme coffeedigital || true
log "set default theme to coffeedigital"

# 4. Обновляем initramfs, чтобы тема загружалась раньше
update-initramfs -u >>"$LOG" 2>&1
log "update-initramfs -u done"

log "splash_theme setup done"

# 5. Настраиваем вывод лого в териминал ssh для пользователя cdreborn
log "Настраиваем логотип в терминале ssh"
if [-f /usr/local/bin/logo.sh]; then
  chmod +x /usr/local/bin/logo.sh

  TARGET_USER=${1:-cdreborn}
  USER_HOME=$(eval echo "~$TARGET_USER")

  if [ -f "$USER_HOME/.bashrc" ]; then
    # Проверяем, есть ли уже строка вызова
    if ! grep -Fxq "/usr/local/bin/login.sh" "$USER_HOME/.bashrc"; then
      echo "" >> "$USER_HOME/.bashrc"
      echo "# Автозапуск логотипа при входе" >> "$USER_HOME/.bashrc"
      echo "/usr/local/bin/login.sh" >> "$USER_HOME/.bashrc"
      log "[OK] Добавлен вызов login.sh в .bashrc пользователя $TARGET_USER"
    else
      log "[INFO] Вызов login.sh уже есть в .bashrc пользователя $TARGET_USER"
    fi
  else
    log "[WARN] Не найден ~/.bashrc для пользователя $TARGET_USER"
  fi
else
  log "[ERROR] Cкрипт для вывода лого по ssh не найден (/usr/local/bin/logo.sh)"
fi
