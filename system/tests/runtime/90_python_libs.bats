#!/usr/bin/env bats

load "test_helper"

@test "Python Libs: cd-protocol is importable" {
    run python3 -c "import cd_protocol; print('ok')"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "Python Libs: cd-protocol resolves to active_services" {
    # Проверяем, что библиотека загружается из правильного места (через симлинк)
    run python3 -c "import cd_protocol; print(cd_protocol.__file__)"
    [ "$status" -eq 0 ]

    # Ожидаем путь начинающийся с /run/headunit/active_services/lib
    [[ "$output" == "/run/headunit/active_services/lib"* ]]
}
