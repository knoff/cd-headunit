#!/usr/bin/env bats

# Загружаем тестируемую библиотеку
# Путь относительный от файла теста (builder/tests/unit/ -> builder/lib/)
load "../../lib/config_parser.sh"

setup() {
    # Создаем временный файл для каждого теста
    TEST_CONF=$(mktemp)
}

teardown() {
    # Удаляем после теста
    rm -f "$TEST_CONF"
}

@test "ConfigParser: reads simple key-value" {
    # 1. Подготовка данных
    echo "[common]" > "$TEST_CONF"
    echo "TEST_KEY=MyValue" >> "$TEST_CONF"

    # 2. Выполнение (БЕЗ run, чтобы переменные попали в текущий scope)
    # Если функция вернет ошибку, тест упадет тут же
    load_ini_section "$TEST_CONF" "common"

    # 3. Проверка результата (проверяем саму переменную, а не вывод)
    [ "$TEST_KEY" = "MyValue" ]
}

@test "ConfigParser: handles quotes correctly" {
    # 1. Подготовка (ключ с кавычками, как в реальном конфиге)
    echo "[common]" > "$TEST_CONF"
    echo 'QUOTED_KEY="Hello World"' >> "$TEST_CONF"

    # 2. Выполнение
    load_ini_section "$TEST_CONF" "common"

    # 3. Проверка (кавычки должны быть удалены парсером)
    [ "$QUOTED_KEY" = "Hello World" ]
}

@test "ConfigParser: ignores other sections" {
    echo "[other]" > "$TEST_CONF"
    echo "SHOULD_NOT_EXIST=1" >> "$TEST_CONF"
    echo "[common]" > "$TEST_CONF"
    echo "SHOULD_EXIST=1" >> "$TEST_CONF"

    load_ini_section "$TEST_CONF" "common"

    [ -z "$SHOULD_NOT_EXIST" ]
    [ "$SHOULD_EXIST" = "1" ]
}
