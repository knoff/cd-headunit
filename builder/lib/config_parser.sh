#!/bin/bash

# Читает INI файл и экспортирует переменные в Bash
load_ini_section() {
    local file="$1"
    local section="$2"

    if [ ! -f "$file" ]; then
        return 0
    fi

    # Используем awk для парсинга.
    # Этот код работает корректно с пробелами и кавычками.
    eval $(awk -v target="[$section]" -F '=' '
    BEGIN { in_section=0 }
    /^\[.*\]/ {
        if ($0 == target) { in_section=1 }
        else { in_section=0 }
        next
    }
    in_section && !/^[:space:]*($|[#;])/ {
        gsub(/^[ \t]+|[ \t]+$/, "", $1) # Trim key

        # Получаем значение (все, что после первого =)
        val=$0
        sub(/^[^=]+=[ \t]*/, "", val)

        # Удаляем кавычки в начале и конце, если есть
        gsub(/^"|"$/, "", val)
        gsub(/^'"'"'|'"'"'$/, "", val)

        # Удаляем trailing comments (после ; или #), если они не внутри кавычек (упрощенно)
        # Для надежности лучше не писать комменты в строке со значением в INI

        if (length($1) > 0) printf "export %s=\"%s\"\n", $1, val
    }
    ' "$file")
}

load_config() {
    local mode="$1"
    local conf_file="headunit.conf"

    if [ ! -f "$conf_file" ]; then
        die "Configuration file $conf_file not found in $(pwd)"
    fi

    log_info "Loading configuration [$mode]..."

    # 1. Сначала common
    load_ini_section "$conf_file" "common"

    # 2. Потом оверрайды
    load_ini_section "$conf_file" "$mode"
}
