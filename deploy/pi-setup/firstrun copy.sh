#!/bin/sh
set -eux
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Определяем boot dir
BOOT=/boot
[ -d /boot/firmware ] && BOOT=/boot/firmware

LOG="$BOOT/firstrun.log"

# Защита от повторного запуска
if [ -f "$BOOT/.firstrun.done" ]; then
  echo "[SKIP] firstrun уже выполнялся" >> "$LOG"
  # Убираем systemd.run из cmdline.txt
  # systemd.run_success_action обычно установлен в reboot, поэтому выход по коду 0 вызовет цикличную перезагрузку
  sed -i 's| systemd\.[^ ]*||g' "$BOOT/cmdline.txt"
  echo "systemd.run из cmdline.txt убран" >> "$LOG"
  exit 0
fi

echo "[$(date -Iseconds)] [00 Подготовка]" >> "$LOG"

# Конфигурационный файл
CONF="$BOOT/device.conf"
[ -s "$CONF" ] || { echo "[00][FATAL] Конфигурационный файл device.conf не найден" >> "$LOG"; exit 1; }
. "$CONF"
echo "[00] Конфигурационный файл device.conf загружен" >> "$LOG"

# утилиты imager_custom / userconf (с фолбэком)
IMAGER="${IMAGER:-}"; USERCONF="${USERCONF:-}"
[ -z "$IMAGER" ]   && { [ -x "$BOOT/lib/imager_custom" ] && IMAGER="$BOOT/lib/imager_custom"; }
[ -z "$IMAGER" ]   && { [ -x /usr/lib/raspberrypi-sys-mods/imager_custom ] && IMAGER=/usr/lib/raspberrypi-sys-mods/imager_custom; }
[ -z "$USERCONF" ] && { [ -x "$BOOT/lib/userconf" ] && USERCONF="$BOOT/lib/userconf"; }
[ -z "$USERCONF" ] && { [ -x /usr/lib/userconf-pi/userconf ] && USERCONF=/usr/lib/userconf-pi/userconf; }
[ -x "$IMAGER" ] && [ -x "$USERCONF" ] || { echo "[00][FATAL] Утилиты imager_custom/userconf не найдены"; exit 1; }
echo "[00] Утилиты imager_custom/userconf загружены" >> "$LOG"

# Разрешаем запись на корневой раздел
mount -o remount,rw / || { echo "[warn] remount / rw failed" >> "$LOG"; exit 1; }
echo "[00] Запись на корневой раздел разрешена" >> "$LOG"

# user+password (с дефолтами)
echo "[$(date -Iseconds)] [01 Настройка пользователей]" >> "$LOG"
USER_NAME="${USER_NAME:-cdreborn}"
USER_PASSWORD="${USER_PASSWORD:-brewme}"
if command -v openssl >/dev/null 2>&1; then
  HASH="$(openssl passwd -6 "$USER_PASSWORD" 2>/dev/null || true)"
  [ -n "$HASH" ] && "$USERCONF" "$USER_NAME" "$HASH"
fi
getent group docker >/dev/null 2>&1 || groupadd -r docker 2>/dev/null || true
usermod -aG sudo "$USER_NAME" 2>/dev/null || true
usermod -aG docker "$USER_NAME" 2>/dev/null || true
echo "[01] Пользователи настроены" >> "$LOG"

echo "[$(date -Iseconds)] [02 Настройка сети]" >> "$LOG"
# hostname
[ -n "${DEVICE_HOSTNAME:-}" ] && "$IMAGER" set_hostname "$DEVICE_HOSTNAME" || true
echo "[02] Установлено имя хоста" >> "$LOG"
# SSH
"$IMAGER" enable_ssh || true
echo "[02] Доступ по SSH открыт" >> "$LOG"

# Wi-Fi (HEX если можем, иначе plaintext)
SSID="${WIFI_SSID:-}"; PASS="${WIFI_PASS:-}"; COUNTRY="${WIFI_COUNTRY:-RU}"
if [ -n "$SSID" ]; then
  if [ -n "$PASS" ] && command -v wpa_passphrase >/dev/null 2>&1; then
    PSK_HEX="$(wpa_passphrase "$SSID" "$PASS" | awk '/^\s*psk=/{if ($0 !~ /^#/) print $0}' | tail -n1 | cut -d= -f2)"
    if [ -n "$PSK_HEX" ]; then "$IMAGER" set_wlan "$SSID" "$PSK_HEX" "$COUNTRY"; else "$IMAGER" set_wlan -p "$SSID" "$PASS" "$COUNTRY"; fi
  else
    "$IMAGER" set_wlan -p "$SSID" "$PASS" "$COUNTRY"
  fi
  echo "[02] WiFi сеть настроена" >> "$LOG"
fi

echo "[$(date -Iseconds)] [03 Копирование конфигурационных файлов и скриптов]" >> "$LOG"
# Копируем конфигурационные файлы
cp -rT "$BOOT/files/etc" /etc/ || { echo "[warn] /etc copy failed" >> "$LOG"; exit 1; }
cp -rT "$BOOT/files/usr/local" /usr/local/ || { echo "[warn] /usr/local copy failed" >> "$LOG"; exit 1; }
echo "[03] Конфигурационные файлы и скрипты скопированы" >> "$LOG"

# Обеспечиваем права
chmod +x /usr/local/bin/tty-login.sh
chmod +x "$BOOT/scripts/"*.sh
echo "[03] Права на запуск скриптов установлены" >> "$LOG"

echo "[$(date -Iseconds)] [04 Настройка автологина]" >> "$LOG"
# Настройка автологина
systemctl enable getty@tty1.service || true
echo "[04] Автологин активирован" >> "$LOG"

echo "[$(date -Iseconds)] [05 Настройка сервиса запуска из boot/scripts]" >> "$LOG"
# Настройка сервиса запуска из boot/scripts
systemctl daemon-reload || true
systemctl enable getty@tty1.service
echo "[05] Сервис запуска настроен" >> "$LOG"

echo "[$(date -Iseconds)] [06 Прочие настройки]" >> "$LOG"
# TZ/Keymap
"$IMAGER" set_timezone "${TIMEZONE:-Europe/Moscow}" || true
echo "[06] Установлен часовой пояс ${TIMEZONE:-Europe/Moscow}" >> "$LOG"
"$IMAGER" set_keymap   "${KEYMAP:-us}" || true
echo "[06] Раскладка клавиатуры по умолчанию ${KEYMAP:-us}" >> "$LOG"


echo "[$(date -Iseconds)] [07 Очистка]" >> "$LOG"
# Помечаем, что загрузка первого запуска завершена
touch "$BOOT/.firstrun.done"
echo "[07] флаг первого запуска установлен" >> "$LOG"

# Убираем systemd.run из cmdline.txt
sed -i 's| systemd\.[^ ]*||g' "$BOOT/cmdline.txt"
echo "[07] systemd.run из cmdline.txt убран" >> "$LOG"

sync
sleep 2
reboot
