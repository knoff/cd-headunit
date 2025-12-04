#!/bin/sh
set -eux
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

################################################################################
# 00. Подготовка
################################################################################

# Определяем boot dir
BOOT=/boot
[ -d /boot/firmware ] && BOOT=/boot/firmware

LOG="$BOOT/firstrun.log"

# Защита от повторного запуска
if [ -f "$BOOT/.firstrun.done" ]; then
  echo "[SKIP] firstrun уже выполнялся" >> "$LOG"
  # Убираем systemd.run из cmdline.txt
  sed -i 's| systemd\.[^ ]*||g' "$BOOT/cmdline.txt"
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
[ -x "$IMAGER" ] && [ -x "$USERCONF" ] || { echo "[00][FATAL] Утилиты imager_custom/userconf не найдены" >> "$LOG"; exit 1; }
echo "[00] Утилиты imager_custom/userconf загружены" >> "$LOG"

################################################################################
# 01. Разметка диска (MBR: p1 boot, p2 rootA, p3 rootB, p4 extended, p5 factory, p6 data)
################################################################################
echo "[$(date -Iseconds)] [01 Разметка диска]" >> "$LOG"

DEV="/dev/mmcblk0"
P1="${DEV}p1"; P2="${DEV}p2"; P3="${DEV}p3"; P4="${DEV}p4"; P5="${DEV}p5"; P6="${DEV}p6"

# Размеры по умолчанию (можно переопределить в device.conf)
TARGET_P2_GB="${TARGET_P2_GB:-4}"   # rootA
TARGET_P3_GB="${TARGET_P3_GB:-4}"   # rootB
TARGET_P5_GB="${TARGET_P5_GB:-4}"   # factory
# data (p6) — остаток диска автоматически

# если p3 и p6 уже есть — считаем разметку выполненной
need_part=1
if lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$' && lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p6$'; then
  need_part=0
fi

if [ "$need_part" -eq 0 ]; then
  log "[01] Разметка уже выполнена — пропускаю"
else
  # Проверка наличия инструментов
  for b in sfdisk rsync resize2fs partprobe partx udevadm blkid mkfs.ext4; do
    command -v "$b" >/dev/null 2>&1 || { echo "[01][FATAL] Нет бинарника: $b" >> "$LOG"; exit 1; }
  done

  # Читаем геометрию через sfdisk --json
  JSON="$(sfdisk --json "$DEV")" || { echo "[01][FATAL] sfdisk --json $DEV" >> "$LOG"; exit 1; }

  # Вычисления:
  sectors_per_mib=2048
  gb_to_sectors() { awk -v g="$1" 'BEGIN{printf "%.0f", g*1024*1024*1024/512}'; }
  align_up() { awk -v x="$1" -v a="$sectors_per_mib" 'BEGIN{print ( ( (x + a - 1) / a ) * a ) }'; }

  # Текущий p2 (старт/размер)
  P2_START=$(echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/start/{print $3; exit}')
  P2_SIZE=$( echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/size/{print $3; exit}')
  DISK_SECTORS=$(cat "/sys/block/$(basename $DEV)/size")
  [ -n "$P2_START" ] && [ -n "$P2_SIZE" ] || { echo "[01][FATAL] Не удалось прочитать p2 из sfdisk --json" >> "$LOG"; exit 1; }
  P2_END=$((P2_START + P2_SIZE - 1))

  echo "[01] disk=$DISK_SECTORS p2=$P2_START+$P2_SIZE end=$P2_END" >> "$LOG"

  P2_TARGET_SECTORS=$(gb_to_sectors "$TARGET_P2_GB")
  P3_SIZE_SECTORS=$(gb_to_sectors "$TARGET_P3_GB")
  P5_SIZE_SECTORS=$(gb_to_sectors "$TARGET_P5_GB")

  # p2: НЕ уменьшаем (опасно). Если меньше целевого — увеличим до нужного размера,
  # если больше — прерываемся (разметка случилась раньше).
  if [ "$P2_SIZE" -gt "$P2_TARGET_SECTORS" ]; then
    echo "[01][FATAL] p2 уже > ${TARGET_P2_GB}G (возможно root был расширен до всей карты до firstrun)." >> "$LOG"
    exit 1
  fi

  if [ "$P2_SIZE" -lt "$P2_TARGET_SECTORS" ]; then
    printf "start=%s, size=%s, type=83\n" "$P2_START" "$P2_TARGET_SECTORS" | sfdisk --no-reread -N 2 "$DEV"
    partprobe "$DEV" || true; partx -u "$DEV" || true; udevadm settle || true
    # расширяем ФС до новых границ p2
    resize2fs "$P2" >> "$LOG" 2>&1 || true

    # перечитываем геометрию
    JSON="$(sfdisk --json "$DEV")"
    P2_START=$(echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/start/{print $3; exit}')
    P2_SIZE=$( echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/size/{print $3; exit}')
    P2_END=$((P2_START + P2_SIZE - 1))
  fi

  # План: p3 (rootB), p4 extended (весь хвост), p5 (factory фикс), p6 (data остаток)
  NEXT_START=$(align_up $((P2_END + 1)))
  P3_START="$NEXT_START"; P3_END=$((P3_START + P3_SIZE_SECTORS - 1))
  P4_EXT_START=$(align_up $((P3_END + 1))); P4_EXT_END=$((DISK_SECTORS - 1))
  P5_START=$(align_up $((P4_EXT_START + sectors_per_mib))); P5_END=$((P5_START + P5_SIZE_SECTORS - 1))
  P6_START=$(align_up $((P5_END + 1))) # без размера — до конца

  set -x
  exec 2>>"$LOG"

  echo "[01] plan: p3 ${P3_START}-${P3_END}; p4ext ${P4_EXT_START}-${P4_EXT_END}; p5 ${P5_START}-${P5_END}; p6 start=${P6_START}" >> "$LOG"

  # Создать p3/p4/p5/p6 (идемпотентно)
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$' || { echo "start=${P3_START}, size=$((P3_END-P3_START+1)), type=83" | sfdisk --no-reread -N 3 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p4$' || { echo "start=${P4_EXT_START}, size=$((P4_EXT_END-P4_EXT_START+1)), type=5"  | sfdisk --no-reread -N 4 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p5$' || { echo "start=${P5_START}, size=$((P5_END-P5_START+1)), type=83"        | sfdisk --no-reread -N 5 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p6$' || { echo "type=83"                                                           | sfdisk --no-reread -N 6 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
  echo "[01] Разделы созданы" >> "$LOG"
  sleep 2

  # --- безопасное форматирование вновь созданных разделов ---
  # важная цель: не «уронить» систему, если устройства появятся с задержкой,
  # и не дёрнуть mkfs до того, как udev закончит обработку.
  # 1) небольшая стабилизация udev и таблицы
  udevadm settle || true
  partprobe "$DEV" || true
  partx -u "$DEV" || true
  udevadm settle || true

  # 2) функция ожидания появления блочного устройства
  wait_part() {
    _dev="$1"; _name="$2"
    i=0
    while [ $i -lt 40 ]; do  # до ~8 секунд
      if [ -b "$(_dev)" ] 2>/dev/null; then
        return 0
      fi
      sleep 0.2
      udevadm settle -t 2 || true
      i=$((i+1))
    done
    echo "[$(date -Iseconds)] [01][FATAL] ${_name} не появился как блочное устройство" >> "$LOG"
    exit 1
  }
  # 3) дождаться появления p3/p5/p6
  wait_part "echo $P3" "p3"
  wait_part "echo $P5" "p5"
  wait_part "echo $P6" "p6"

  echo "[01] Форматируем разделы p3, p5, p6" >> "$LOG"
  # 4) форматирование только при отсутствии ФС с «жёсткой» синхронизацией
  if [ -z "$(blkid -s TYPE -o value "$P3" 2>/dev/null)" ]; then
    mkfs.ext4 -F -L rootfs_B "$P3" >> "$LOG" 2>&1 || true
    sync
  fi

  if [ -z "$(blkid -s TYPE -o value "$P5" 2>/dev/null)" ]; then
    mkfs.ext4 -F -L factory "$P5" >> "$LOG" 2>&1 || true
    sync
  fi

  if [ -z "$(blkid -s TYPE -o value "$P6" 2>/dev/null)" ]; then
    mkfs.ext4 -F -L data "$P6" >> "$LOG" 2>&1 || true
    sync
  fi
  echo "[01] Форматирование завершено" >> "$LOG"
  # Клон root A → B (rsync), если ещё не делали
  #if ! [ -e /mnt/rootB/etc/fstab ]; then
  #  mkdir -p /mnt/rootB
  #  mount "$P3" /mnt/rootB
  #  rsync -aHAX --delete --exclude={"/proc/*","/sys/*","/dev/*","/run/*","/tmp/*","/lost+found","/mnt/*","/media/*"} / /mnt/rootB
  #  umount /mnt/rootB
  #fi

  # fstab (A и B) из шаблона
  # fstab: шаблон ищем в нескольких стандартных местах на BOOT
  FSTAB_TPL=""
  for c in "$BOOT/fstab.template" "$BOOT/files/etc/fstab.template" "$BOOT/first-boot/fstab.template"; do
    [ -s "$c" ] && { FSTAB_TPL="$c"; break; }
  done
  if [ -z "$FSTAB_TPL" ]; then
    echo "[WARN] fstab.template не найден на BOOT — пропускаю генерацию fstab" >> "$LOG"
  else
    UUID_P1=$(blkid -s PARTUUID -o value "$P1")
    UUID_P2=$(blkid -s PARTUUID -o value "$P2")
    UUID_P3=$(blkid -s PARTUUID -o value "$P3")
    UUID_P5=$(blkid -s PARTUUID -o value "$P5")
    UUID_P6=$(blkid -s PARTUUID -o value "$P6")

    install -D -m0644 "$BOOT/fstab.template" /etc/fstab
    sed -i \
    -e "s#__BOOT_PARTUUID__#${UUID_P1}#g" \
    -e "s#__ROOT_PARTUUID__#${UUID_P2}#g" \
    -e "s#__DATA_PARTUUID__#${UUID_P6}#g" \
    -e "s#__FACTORY_PARTUUID__#${UUID_P5}#g" \
    -e "s#__BOOT_MNT__#${BOOT}#g" \
    /etc/fstab

    mount "$P3" /mnt/rootB
    install -D -m0644 "$BOOT/fstab.template" /mnt/rootB/etc/fstab
    sed -i \
    -e "s#__BOOT_PARTUUID__#${UUID_P1}#g" \
    -e "s#__ROOT_PARTUUID__#${UUID_P3}#g" \
    -e "s#__DATA_PARTUUID__#${UUID_P6}#g" \
    -e "s#__FACTORY_PARTUUID__#${UUID_P5}#g" \
    -e "s#__BOOT_MNT__#${BOOT}#g" \
    /mnt/rootB/etc/fstab
    umount /mnt/rootB
    echo "[01] fstab(A,B) сгенерированы из шаблона" >> "$LOG"
  fi
  echo "[01] Разметка завершена" >> "$LOG"
fi

# Разрешаем запись на корневой раздел
mount -o remount,rw / || { echo "[warn] remount / rw failed" >> "$LOG"; exit 1; }
echo "[01] Запись на корневой раздел разрешена" >> "$LOG"

################################################################################
# 02-07. Пользователи, сеть, копирование и т.д.
################################################################################

echo "[$(date -Iseconds)] [02 Настройка пользователей]" >> "$LOG"
USER_NAME="${USER_NAME:-cdreborn}"
USER_PASSWORD="${USER_PASSWORD:-brewme}"
if command -v openssl >/dev/null 2>&1; then
  HASH="$(openssl passwd -6 "$USER_PASSWORD" 2>/dev/null || true)"
  [ -n "$HASH" ] && "$USERCONF" "$USER_NAME" "$HASH"
fi
getent group docker >/dev/null 2>&1 || groupadd -r docker 2>/dev/null || true
usermod -aG sudo "$USER_NAME" 2>/dev/null || true
usermod -aG docker "$USER_NAME" 2>/dev/null || true
echo "[02] Пользователи настроены" >> "$LOG"

echo "[$(date -Iseconds)] [03 Настройка сети]" >> "$LOG"
[ -n "${DEVICE_HOSTNAME:-}" ] && "$IMAGER" set_hostname "$DEVICE_HOSTNAME" || true
echo "[03] Установлено имя хоста" >> "$LOG"
"$IMAGER" enable_ssh || true
echo "[03] Доступ по SSH открыт" >> "$LOG"

SSID="${WIFI_SSID:-}"; PASS="${WIFI_PASS:-}"; COUNTRY="${WIFI_COUNTRY:-RU}"
if [ -n "$SSID" ]; then
  if [ -n "$PASS" ] && command -v wpa_passphrase >/dev/null 2>&1; then
    PSK_HEX="$(wpa_passphrase "$SSID" "$PASS" | awk '/^\s*psk=/{if ($0 !~ /^#/) print $0}' | tail -n1 | cut -d= -f2)"
    if [ -n "$PSK_HEX" ]; then "$IMAGER" set_wlan "$SSID" "$PSK_HEX" "$COUNTRY"; else "$IMAGER" set_wlan -p "$SSID" "$PASS" "$COUNTRY"; fi
  else
    "$IMAGER" set_wlan -p "$SSID" "$PASS" "$COUNTRY"
  fi
  echo "[03] WiFi сеть настроена" >> "$LOG"
fi

echo "[$(date -Iseconds)] [04 Копирование конфигурационных файлов и скриптов]" >> "$LOG"
cp -rT "$BOOT/files/etc" /etc/ || { echo "[warn] /etc copy failed" >> "$LOG"; exit 1; }
cp -rT "$BOOT/files/usr/local" /usr/local/ || { echo "[warn] /usr/local copy failed" >> "$LOG"; exit 1; }
echo "[04] Конфигурационные файлы и скрипты скопированы" >> "$LOG"

chmod +x /usr/local/bin/tty-login.sh
[ -d "$BOOT/scripts" ] && chmod +x "$BOOT/scripts/"*.sh || true
echo "[04] Права на запуск скриптов установлены" >> "$LOG"

echo "[$(date -Iseconds)] [05 Настройка автологина]" >> "$LOG"
systemctl enable getty@tty1.service || true
echo "[05] Автологин активирован" >> "$LOG"

echo "[$(date -Iseconds)] [06 Настройка сервиса запуска из boot/scripts]" >> "$LOG"
systemctl daemon-reload || true
systemctl enable getty@tty1.service
echo "[06] Сервис запуска настроен" >> "$LOG"

echo "[$(date -Iseconds)] [07 Прочие настройки]" >> "$LOG"
"$IMAGER" set_timezone "${TIMEZONE:-Europe/Moscow}" || true
echo "[07] Установлен часовой пояс ${TIMEZONE:-Europe/Moscow}" >> "$LOG"
"$IMAGER" set_keymap   "${KEYMAP:-us}" || true
echo "[07] Раскладка клавиатуры по умолчанию ${KEYMAP:-us}" >> "$LOG"

# ========================================================================================
# 08. КЛОНИРОВАНИЕ ROOT A -> B (в самом конце)
# ========================================================================================
echo "[$(date -Iseconds)] [08] Клонирование A->B старт" >> "$LOG"

if lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$'; then
  mkdir -p /mnt/rootB
  mount "$P3" /mnt/rootB
  if mountpoint -q /mnt/rootB; then
    if [ ! -e /mnt/rootB/etc/fstab ]; then
      # маркер, чтобы точно исключить себя
      touch /.cd-rootfs-stamp
      rsync -aHAXx --delete-after --numeric-ids \
        --exclude='/proc/**' \
        --exclude='/sys/**' \
        --exclude='/dev/**' \
        --exclude='/run/**' \
        --exclude='/tmp/**' \
        --exclude='/lost+found/**' \
        --exclude='/mnt/**' \
        --exclude='/media/**' \
        --exclude='/boot/**' \
        --exclude='/etc/fstab' \
        --exclude='/.cd-rootfs-stamp' \
        /  /mnt/rootB/
      rm -f /.cd-rootfs-stamp || true
      umount /mnt/rootB
      echo "[08] Клонирование завершено" >> "$LOG"
    else
      umount /mnt/rootB
      echo "[08] rootB уже содержит систему — пропуск"  >> "$LOG"
    fi
  else
    echo "[08][WARN] /mnt/rootB не смонтирован — пропуск клонирования" >> "$LOG"
  fi
else
  echo "[08][WARN] p3 отсутствует — пропуск клонирования"  >> "$LOG"
fi

# ========================================================================================
# 09. Завершение: флаг, очистка cmdline, перезагрузка
# ========================================================================================

echo "[$(date -Iseconds)] [09 Очистка]" >> "$LOG"
touch "$BOOT/.firstrun.done"
echo "[09] флаг первого запуска установлен" >> "$LOG"
sed -i 's| systemd\.[^ ]*||g' "$BOOT/cmdline.txt"
echo "[09] systemd.run из cmdline.txt убран" >> "$LOG"
sync
sleep 2
reboot
