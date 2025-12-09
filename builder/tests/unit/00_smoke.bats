#!/usr/bin/env bats

@test "Infra: BATS environment is active" {
    # Проверка, что базовые команды bash работают внутри bats
    run echo "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "hello" ]
}

@test "Infra: Can source libs" {
    # Проверка путей: можем ли мы дотянуться до библиотек
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    LIB_DIR="$DIR/../../lib"

    if [ ! -f "$LIB_DIR/utils.sh" ]; then
        skip "utils.sh not found at $LIB_DIR"
    fi

    source "$LIB_DIR/utils.sh"
    # Проверяем, что функция из библиотеки доступна
    [ "$(type -t log_info)" == "function" ]
}
