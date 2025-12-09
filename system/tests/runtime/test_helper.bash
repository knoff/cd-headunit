#!/usr/bin/env bash

# === HELPER FUNCTION: Soft Fail / Warning ===
# Проверяет команду. Если упала — выдает WARN и пропускает тест.
# Использование: check_optional "Сообщение варнинга" <команда> [аргументы]
check_optional() {
    local warning_msg="$1"
    shift

    run "$@"
    if [ "$status" -ne 0 ]; then
        # BATS использует формат 'skip <reason>'
        # Мы добавляем префикс WARN:, который парсит наш health_agent
        skip "WARN: $warning_msg"
    fi
}
