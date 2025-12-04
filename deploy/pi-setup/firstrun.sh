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

KEEP_BOOT_DEVICE_CONF=0
KEEP_BOOT_FSTAB_TEMPLATE=0
MOVE_LOG_TO_DATA=1

SUCCESS=0

on_error() {
  # Логируем фатал и НЕ убираем артефакты для отладки
  echo "[$(date -Iseconds)] [FATAL] firstrun interrupted (see log). Keeping stage markers and boot files." >> "$LOG" || true
  # гарантируем ro для /boot
  if mountpoint -q "$BOOT"; then
    if ! findmnt -no OPTIONS "$BOOT" | grep -qE '(^|,)ro(,|$)'; then
      sync; mount -o remount,ro "$BOOT" || true
    fi
  fi
}
trap on_error ERR

# Защита от повторного запуска целиком
if [ -f "$BOOT/.firstrun.done" ]; then
  echo "[$(date -Iseconds)] [SKIP] firstrun уже выполнялся — снимаю systemd.run и выхожу" >> "$LOG"
  sed -i 's| systemd\.[^ ]*||g' "$BOOT/cmdline.txt" || true
  exit 0
fi

echo "[$(date -Iseconds)] [00 Подготовка]" >> "$LOG"

# Конфигурационный файл
CONF="$BOOT/device.conf"
[ -s "$CONF" ] || { echo "[00][FATAL] Конфигурационный файл device.conf не найден" >> "$LOG"; exit 1; }
# shellcheck disable=SC1090
. "$CONF"
echo "[00] Конфигурационный файл device.conf загружен" >> "$LOG"

# Утилиты imager_custom / userconf (с фолбэком)
IMAGER="${IMAGER:-}"; USERCONF="${USERCONF:-}"
[ -z "$IMAGER" ]   && { [ -x "$BOOT/lib/imager_custom" ] && IMAGER="$BOOT/lib/imager_custom"; }
[ -z "$IMAGER" ]   && { [ -x /usr/lib/raspberrypi-sys-mods/imager_custom ] && IMAGER=/usr/lib/raspberrypi-sys-mods/imager_custom; }
[ -z "$USERCONF" ] && { [ -x "$BOOT/lib/userconf" ] && USERCONF="$BOOT/lib/userconf"; }
[ -z "$USERCONF" ] && { [ -x /usr/lib/userconf-pi/userconf ] && USERCONF=/usr/lib/userconf-pi/userconf; }
[ -x "$IMAGER" ] && [ -x "$USERCONF" ] || { echo "[00][FATAL] Утилиты imager_custom/userconf не найдены" >> "$LOG"; exit 1; }
echo "[00] Утилиты imager_custom/userconf загружены" >> "$LOG"

# Общие переменные устройств
DEV="/dev/mmcblk0"
P1="${DEV}p1"; P2="${DEV}p2"; P3="${DEV}p3"; P4="${DEV}p4"; P5="${DEV}p5"; P6="${DEV}p6"

# Размеры по умолчанию (переопределимы в device.conf)
TARGET_P2_GB="${TARGET_P2_GB:-4}"   # rootA
TARGET_P3_GB="${TARGET_P3_GB:-4}"   # rootB
TARGET_P5_GB="${TARGET_P5_GB:-4}"   # factory

# Мелкие утилиты (потребуются в нескольких стадиях)
need_bins() {
  for b in sfdisk resize2fs partprobe partx udevadm blkid wipefs mkfs.ext4 rsync openssl; do
    command -v "$b" >/dev/null 2>&1 || { echo "[$(date -Iseconds)] [FATAL] Нет бинарника: $b" >> "$LOG"; exit 1; }
  done
}
need_bins

partuuid() { blkid -s PARTUUID -o value "$1"; }

# Хелперы
sectors_per_mib=2048
gb_to_sectors() { awk -v g="$1" 'BEGIN{printf "%.0f", g*1024*1024*1024/512}'; }
align_up() { awk -v x="$1" -v a="$sectors_per_mib" 'BEGIN{print ( ( (x + a - 1) / a ) * a ) }'; }

wait_part() {
  _dev="$1"; _name="$2"
  i=0
  while [ $i -lt 40 ]; do # до ~8 сек
    [ -b "$_dev" ] && return 0
    sleep 0.2
    udevadm settle -t 2 || true
    i=$((i+1))
  done
  echo "[$(date -Iseconds)] [FATAL] ${_name} не появился как блочное устройство" >> "$LOG"
  exit 1
}

################################################################################
# 01. Разметка диска (MBR: p1 boot, p2 rootA, p3 rootB, p4 extended, p5 factory, p6 data)
################################################################################
STAGE_PART="$BOOT/.stage01_parted.done"
if [ -f "$STAGE_PART" ]; then
  echo "[$(date -Iseconds)] [01][SKIP] Разметка уже выполнена" >> "$LOG"
else
  echo "[$(date -Iseconds)] [01 Разметка диска]" >> "$LOG"

  # Читаем геометрию
  JSON="$(sfdisk --json "$DEV")" || { echo "[01][FATAL] sfdisk --json $DEV" >> "$LOG"; exit 1; }

  P2_START=$(echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/start/{print $3; exit}')
  P2_SIZE=$( echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/size/{print $3; exit}')
  DISK_SECTORS=$(cat "/sys/block/$(basename $DEV)/size")
  [ -n "$P2_START" ] && [ -n "$P2_SIZE" ] || { echo "[01][FATAL] Не удалось прочитать p2 из sfdisk --json" >> "$LOG"; exit 1; }
  P2_END=$((P2_START + P2_SIZE - 1))
  echo "[01] disk=$DISK_SECTORS p2=${P2_START}+${P2_SIZE} end=${P2_END}" >> "$LOG"

  P2_TARGET_SECTORS=$(gb_to_sectors "$TARGET_P2_GB")
  P3_SIZE_SECTORS=$(gb_to_sectors "$TARGET_P3_GB")
  P5_SIZE_SECTORS=$(gb_to_sectors "$TARGET_P5_GB")

  if [ "$P2_SIZE" -gt "$P2_TARGET_SECTORS" ]; then
    echo "[01][FATAL] p2 уже > ${TARGET_P2_GB}G (авто-resize успел раньше). Останавливаюсь." >> "$LOG"
    exit 1
  fi

  if [ "$P2_SIZE" -lt "$P2_TARGET_SECTORS" ]; then
    printf "start=%s, size=%s, type=83\n" "$P2_START" "$P2_TARGET_SECTORS" | sfdisk --no-reread -N 2 "$DEV"
    partprobe "$DEV" || true; partx -u "$DEV" || true; udevadm settle || true
    resize2fs "$P2" >> "$LOG" 2>&1 || true
    JSON="$(sfdisk --json "$DEV")"
    P2_START=$(echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/start/{print $3; exit}')
    P2_SIZE=$( echo "$JSON" | awk -F'[:, ]+' '/mmcblk0p2/{f=1} f&&/size/{print $3; exit}')
    P2_END=$((P2_START + P2_SIZE - 1))
  fi

  NEXT_START=$(align_up $((P2_END + 1)))
  P3_START="$NEXT_START"; P3_END=$((P3_START + P3_SIZE_SECTORS - 1))
  P4_EXT_START=$(align_up $((P3_END + 1))); P4_EXT_END=$((DISK_SECTORS - 1))
  P5_START=$(align_up $((P4_EXT_START + sectors_per_mib))); P5_END=$((P5_START + P5_SIZE_SECTORS - 1))
  P6_START=$(align_up $((P5_END + 1))) # без size — остаток

  echo "[01] plan: p3 ${P3_START}-${P3_END}; p4ext ${P4_EXT_START}-${P4_EXT_END}; p5 ${P5_START}-${P5_END}; p6 start=${P6_START}" >> "$LOG"

  # Создание разделов (идемпотентно)
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$' || { echo "start=${P3_START}, size=$((P3_END-P3_START+1)), type=83" | sfdisk --no-reread -N 3 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p4$' || { echo "start=${P4_EXT_START}, size=$((P4_EXT_END-P4_EXT_START+1)), type=5"  | sfdisk --no-reread -N 4 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p5$' || { echo "start=${P5_START}, size=$((P5_END-P5_START+1)), type=83"        | sfdisk --no-reread -N 5 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }
  lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p6$' || { echo "type=83"                                    | sfdisk --no-reread -N 6 "$DEV"; partprobe "$DEV"; partx -u "$DEV"; udevadm settle; }

  echo "[$(date -Iseconds)] [01] Разделы созданы" >> "$LOG"
  touch "$STAGE_PART"
fi

################################################################################
# 02. Форматирование (только если ФС ещё нет) — безопасно
################################################################################
STAGE_FMT="$BOOT/.stage02_format.done"
if [ -f "$STAGE_FMT" ]; then
  echo "[$(date -Iseconds)] [02][SKIP] Форматирование уже выполнено" >> "$LOG"
else
  echo "[$(date -Iseconds)] [02 Форматирование]" >> "$LOG"

  # стабилизация udev/partition
  udevadm settle || true
  partprobe "$DEV" || true
  partx -u "$DEV" || true
  udevadm settle || true

  # дождаться устройств
  wait_part "$P3" "p3"
  wait_part "$P5" "p5"
  wait_part "$P6" "p6"

  # Страховки: разделы существуют и не смонтированы (на всякий случай)
  for P in "$P3" "$P5" "$P6"; do
    if [ ! -b "$P" ]; then
      echo "[$(date -Iseconds)] [02][FATAL] Нет блочного устройства $P" >> "$LOG"
      exit 1
    fi
    # если вдруг смонтирован — отмонтировать
    if findmnt -rn -S "$P" >/dev/null 2>&1; then
      umount -lf "$P" || true
    fi
  done
  udevadm settle || true

  # Сносим любые старые сигнатуры и создаём ФС
  wipefs -a "$P3" >/dev/null 2>&1 || true
  mkfs.ext4 -F -L rootfs_B "$P3" >> "$LOG" 2>&1

  wipefs -a "$P5" >/dev/null 2>&1 || true
  mkfs.ext4 -F -L factory  "$P5" >> "$LOG" 2>&1

  wipefs -a "$P6" >/dev/null 2>&1 || true
  mkfs.ext4 -F -L data     "$P6" >> "$LOG" 2>&1

  echo "[$(date -Iseconds)] [02] Форматирование завершено" >> "$LOG"
  touch "$STAGE_FMT"
fi

################################################################################
# 02.5. Формирование структуры на /data
################################################################################

echo "[$(date -Iseconds)] [02.5 Подготовка /data]" >> "$LOG"
mkdir -p /mnt/data
mount -t ext4 "$P6" /mnt/data

# убираем резерв ext4 на /data (по умолчанию 5%)
tune2fs -m 0 "$P6" >> "$LOG" 2>&1 || true

# базовая структура
mkdir -p /mnt/data/{etc_upper,etc_work,config,log}
sync
umount /mnt/data


################################################################################
# 03. Генерация fstab (A и B) из шаблона
################################################################################
STAGE_FSTAB="$BOOT/.stage03_fstab.done"
if [ -f "$STAGE_FSTAB" ]; then
  echo "[$(date -Iseconds)] [03][SKIP] fstab уже создан" >> "$LOG"
else
  echo "[$(date -Iseconds)] [03 Генерация fstab]" >> "$LOG"
  FSTAB_TPL=""
  for c in "$BOOT/fstab.template" "$BOOT/files/etc/fstab.template" "$BOOT/first-boot/fstab.template"; do
    [ -s "$c" ] && { FSTAB_TPL="$c"; break; }
  done
  if [ -z "$FSTAB_TPL" ]; then
    echo "[03][WARN] fstab.template не найден — пропуск" >> "$LOG"
  else
    UUID_P1=$(blkid -s PARTUUID -o value "$P1" 2>/dev/null || true)
    UUID_P2=$(blkid -s PARTUUID -o value "$P2" 2>/dev/null || true)
    UUID_P3=$(blkid -s PARTUUID -o value "$P3" 2>/dev/null || true)
    UUID_P5=$(blkid -s PARTUUID -o value "$P5" 2>/dev/null || true)
    UUID_P6=$(blkid -s PARTUUID -o value "$P6" 2>/dev/null || true)

    if [ -n "$UUID_P1" ] && [ -n "$UUID_P2" ] && [ -n "$UUID_P6" ] && [ -n "$UUID_P5" ]; then
      install -D -m0644 "$FSTAB_TPL" /etc/fstab
      sed -i \
        -e "s#__BOOT_PARTUUID__#${UUID_P1}#g" \
        -e "s#__ROOT_PARTUUID__#${UUID_P2}#g" \
        -e "s#__DATA_PARTUUID__#${UUID_P6}#g" \
        -e "s#__FACTORY_PARTUUID__#${UUID_P5}#g" \
        -e "s#__BOOT_MNT__#${BOOT}#g" \
        /etc/fstab

      mkdir -p /mnt/rootB

      mkdir -p /mnt/rootB
      if ! mount -t ext4 "$P3" /mnt/rootB; then
        echo "[$(date -Iseconds)] [03][FATAL] Не удалось смонтировать $P3 (возможно, раздел не отформатирован)" >> "$LOG"
        exit 1
      fi
      install -D -m0644 "$FSTAB_TPL" /mnt/rootB/etc/fstab
      sed -i \
        -e "s#__BOOT_PARTUUID__#${UUID_P1}#g" \
        -e "s#__ROOT_PARTUUID__#${UUID_P3}#g" \
        -e "s#__DATA_PARTUUID__#${UUID_P6}#g" \
        -e "s#__FACTORY_PARTUUID__#${UUID_P5}#g" \
        -e "s#__BOOT_MNT__#${BOOT}#g" \
        /mnt/rootB/etc/fstab
      umount /mnt/rootB
      echo "[03] fstab(A,B) сгенерированы" >> "$LOG"
    else
      echo "[03][WARN] PARTUUID недостаточны для генерации fstab — пропуск" >> "$LOG"
    fi
  fi
  touch "$STAGE_FSTAB"
fi

################################################################################
# 04. Настройка пользователей
################################################################################
STAGE_USER="$BOOT/.stage04_users.done"
if [ -f "$STAGE_USER" ]; then
  echo "[$(date -Iseconds)] [04][SKIP] Пользователи уже настроены" >> "$LOG"
else
  echo "[$(date -Iseconds)] [04 Настройка пользователей]" >> "$LOG"
  USER_NAME="${USER_NAME:-cdreborn}"
  USER_PASSWORD="${USER_PASSWORD:-brewme}"
  if command -v openssl >/dev/null 2>&1; then
    HASH="$(openssl passwd -6 "$USER_PASSWORD" 2>/dev/null || true)"
    [ -n "$HASH" ] && "$USERCONF" "$USER_NAME" "$HASH" || true
  fi
  getent group docker >/dev/null 2>&1 || groupadd -r docker 2>/dev/null || true
  usermod -aG sudo   "$USER_NAME" 2>/dev/null || true
  usermod -aG docker "$USER_NAME" 2>/dev/null || true
  echo "[$(date -Iseconds)] [04] Пользователи/группы настроены" >> "$LOG"
  touch "$STAGE_USER"
fi

################################################################################
# 05. Настройка сети
################################################################################
STAGE_NET="$BOOT/.stage05_network.done"
if [ -f "$STAGE_NET" ]; then
  echo "[$(date -Iseconds)] [05][SKIP] Сеть уже настроена" >> "$LOG"
else
  echo "[$(date -Iseconds)] [05 Настройка сети]" >> "$LOG"
  [ -n "${DEVICE_HOSTNAME:-}" ] && "$IMAGER" set_hostname "$DEVICE_HOSTNAME" || true
  "$IMAGER" enable_ssh || true
  SSID="${WIFI_SSID:-}"; PASS="${WIFI_PASS:-}"; COUNTRY="${WIFI_COUNTRY:-RU}"
  if [ -n "$SSID" ]; then
    if [ -n "$PASS" ] && command -v wpa_passphrase >/dev/null 2>&1; then
      PSK_HEX="$(wpa_passphrase "$SSID" "$PASS" | awk '/^\s*psk=/{if ($0 !~ /^#/) print $0}' | tail -n1 | cut -d= -f2)"
      if [ -n "$PSK_HEX" ]; then "$IMAGER" set_wlan "$SSID" "$PSK_HEX" "$COUNTRY"; else "$IMAGER" set_wlan -p "$SSID" "$PASS" "$COUNTRY"; fi
    else
      "$IMAGER" set_wlan -p "$SSID" "$PASS" "$COUNTRY"
    fi
  fi
  echo "[$(date -Iseconds)] [05] Сеть настроена" >> "$LOG"
  touch "$STAGE_NET"
fi

################################################################################
# 06. Копирование конфигов/скриптов проекта и конфигов
################################################################################
STAGE_FILES="$BOOT/.stage06_files.done"
if [ -f "$STAGE_FILES" ]; then
  echo "[$(date -Iseconds)] [06][SKIP] Файлы уже скопированы" >> "$LOG"
else
  echo "[$(date -Iseconds)] [06 Копирование конфигурационных файлов и скриптов]" >> "$LOG"
  if [ -d "$BOOT/files/etc" ]; then
    cp -rT "$BOOT/files/etc" /etc/ || true
  fi
  if [ -d "$BOOT/files/usr/local" ]; then
    cp -rT "$BOOT/files/usr/local" /usr/local/ || true
  fi
  chmod +x /usr/local/bin/tty-login.sh 2>/dev/null || true
  chmod 0755 /usr/local/sbin/boot-*.sh || true
  [ -d "$BOOT/scripts" ] && chmod +x "$BOOT/scripts/"*.sh 2>/dev/null || true
  echo "[$(date -Iseconds)] [06] Конфиги/скрипты скопированы" >> "$LOG"
  touch "$STAGE_FILES"
fi

################################################################################
# 07. Сервисы/автологин/локаль/таймзона
################################################################################
STAGE_SERV="$BOOT/.stage07_services.done"
if [ -f "$STAGE_SERV" ]; then
  echo "[$(date -Iseconds)] [07][SKIP] Сервисы уже настроены" >> "$LOG"
else
  echo "[$(date -Iseconds)] [07 Настройка сервисов]" >> "$LOG"
  # Разрешаем запись на корневой раздел (если ещё не включили)
  mount -o remount,rw / || { echo "[$(date -Iseconds)] [07][WARN] remount / rw failed" >> "$LOG"; }

  systemctl enable getty@tty1.service || true
  systemctl daemon-reload || true

  systemctl enable sync-before-shutdown.service || true
  systemctl daemon-reload || true

  "$IMAGER" set_timezone "${TIMEZONE:-Europe/Moscow}" || true
  "$IMAGER" set_keymap   "${KEYMAP:-us}" || true
  echo "[$(date -Iseconds)] [07] Автологин/сервисы/локаль/таймзона применены" >> "$LOG"
  touch "$STAGE_SERV"
fi

################################################################################
# 08. Клонирование ROOT A -> B (в самом конце)
################################################################################
STAGE_CLONE="$BOOT/.stage08_clone.done"
if [ -f "$STAGE_CLONE" ]; then
  echo "[$(date -Iseconds)] [08][SKIP] Клонирование уже выполнено" >> "$LOG"
else
  echo "[$(date -Iseconds)] [08 Клонирование A->B]" >> "$LOG"
  if lsblk -nr -o NAME "$DEV" | grep -q '^mmcblk0p3$'; then
    mkdir -p /mnt/rootB
    mount "$P3" /mnt/rootB
    if mountpoint -q /mnt/rootB; then
      if [ ! -e /mnt/rootB/.rootB.cloned ]; then
        # маркер, чтобы исключить самих себя
        touch /.cd-rootfs-stamp
        # NB: для первого клона безопасен --delete-after; для OTA потом сменим на --delete-before
        rsync -aHAXx --delete-after --numeric-ids \
          --exclude='/proc/**' \
          --exclude='/sys/**'  \
          --exclude='/dev/**'  \
          --exclude='/run/**'  \
          --exclude='/tmp/**'  \
          --exclude='/lost+found/**' \
          --exclude='/mnt/**'  \
          --exclude='/media/**'\
          --exclude='/boot/**' \
          --exclude='/etc/fstab' \
          --exclude='/.cd-rootfs-stamp' \
          /  /mnt/rootB/
        rm -f /.cd-rootfs-stamp || true
        touch /mnt/rootB/.rootB.cloned
        umount /mnt/rootB
        echo "[$(date -Iseconds)] [08] Клонирование завершено" >> "$LOG"
      else
        umount /mnt/rootB
        echo "[$(date -Iseconds)] [08][SKIP] rootB уже содержит систему — пропуск" >> "$LOG"
      fi
    else
      echo "[$(date -Iseconds)] [08][WARN] /mnt/rootB не смонтирован — пропуск клонирования" >> "$LOG"
    fi
  else
    echo "[$(date -Iseconds)] [08][WARN] p3 отсутствует — пропуск клонирования" >> "$LOG"
  fi
  touch "$STAGE_CLONE"
fi

################################################################################
# 09. Завершение: флаг, очистка cmdline, перезагрузка
################################################################################
echo "[$(date -Iseconds)] [09 Очистка]" >> "$LOG"
touch "$BOOT/.firstrun.done"
echo "[$(date -Iseconds)] [09] флаг первого запуска установлен" >> "$LOG"
sed -i 's| systemd\.[^ ]*||g' "$BOOT/cmdline.txt" || true
echo "[$(date -Iseconds)] [09] systemd.run из cmdline.txt убран" >> "$LOG"

boot_path() { [ -d /boot/firmware ] && echo /boot/firmware || echo /boot; }

cleanup_success() {
  local BOOT; BOOT="$(boot_path)"

  echo "[$(date -Iseconds)] [99 Очистка]" >> "$LOG"

  # 99.1 Перенос лога в /data/log (если доступно)
  if [ "${MOVE_LOG_TO_DATA:-1}" = "1" ] && mountpoint -q /data; then
    mkdir -p /data/log
    local LOG_DST="/data/log/firstrun-$(date +%Y%m%d-%H%M%S).log"
    cp -a "$LOG" "$LOG_DST" 2>/dev/null || true
    echo "[$(date -Iseconds)] [99] Лог скопирован в $LOG_DST" >> "$LOG"
  fi

  # 99.2 Временный rw для BOOT
  if mountpoint -q "$BOOT"; then
    if findmnt -no OPTIONS "$BOOT" | grep -qE '(^|,)ro(,|$)'; then
      mount -o remount,rw "$BOOT"
    fi
  fi

  # 99.3 Удаление stage-маркеров
  find "$BOOT" -maxdepth 1 -type f -name '.stage*.done' -print -delete 2>/dev/null || true

  # 99.4 Удаление временных/служебных директорий, если они есть на BOOT
  # (оставляем пользовательские входные файлы по флагам)
  # ВНИМАНИЕ: не трогаем device.conf и fstab.template, если включены флаги KEEP_*
  for f in "$BOOT/firstrun.sh" "$BOOT/tty-login.log"; do
    [ -e "$f" ] && rm -f "$f" || true
  done

  # lib могли использоваться для первой загрузки — удалим безопасно
  [ -d "$BOOT/lib" ]     && rm -rf "$BOOT/lib"     || true

  # Сохраняем device.conf/fstab.template по флагам
  if [ "${KEEP_BOOT_DEVICE_CONF:-1}" != "1" ]; then
    [ -e "$BOOT/device.conf" ] && rm -f "$BOOT/device.conf" || true
  fi
  if [ "${KEEP_BOOT_FSTAB_TEMPLATE:-1}" != "1" ]; then
    [ -e "$BOOT/fstab.template" ] && rm -f "$BOOT/fstab.template" || true
  fi

  # 99.5 Возврат BOOT в ro
  sync
  mount -o remount,ro "$BOOT" || true

  echo "[$(date -Iseconds)] [99] Очистка завершена" >> "$LOG"
}

SUCCESS=1

# смонтируем /data, чтобы забрать лог (если ещё не смонтирована системой)
if ! mountpoint -q /data; then
  # подставь правильный путь к разделу data
  mount -t ext4 "$P6" /data 2>/dev/null || true
fi

cleanup_success

sync
sleep 2
reboot
