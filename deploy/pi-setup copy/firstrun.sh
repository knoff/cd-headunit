#!/usr/bin/env bash
# log_my_path.sh — записывает полный путь до самого скрипта в лог и выходит с кодом 1

# Лог-файл (по умолчанию — ./script.log, можно задать переменной окружения LOGFILE)
LOGFILE="${LOGFILE:-./script.log}"

# Вычисляем полный путь до скрипта. Попробуем realpath, затем readlink -f, иначе — portable fallback.
SCRIPT_ARG="${BASH_SOURCE[0]:-$0}"

if command -v realpath >/dev/null 2>&1; then
  SCRIPT_PATH="$(realpath "$SCRIPT_ARG")"
elif command -v readlink >/dev/null 2>&1; then
  SCRIPT_PATH="$(readlink -f "$SCRIPT_ARG")"
else
  # Портативный способ: абсолютный путь до каталога + имя файла
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_ARG")" >/dev/null 2>&1 && pwd -P)"
  SCRIPT_PATH="$SCRIPT_DIR/$(basename "$SCRIPT_ARG")"
fi

# Запись в лог (добавляем новую строку)
echo "$SCRIPT_PATH" >> "$LOGFILE"

# Завершаем с кодом 1
exit 1
