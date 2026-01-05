#!/usr/bin/env bats

@test "Linker: Service finished successfully" {
    # Сервис oneshot, он должен быть active (exited)
    run systemctl is-active headunit-boot-linker.service
    [ "$status" -eq 0 ]
}

@test "Linker: Active APP symlink created" {
    [ -L "/run/headunit/active_app" ]
    # Проверяем, что ссылка не битая
    [ -e "/run/headunit/active_app" ]
}

@test "Linker: Active SERVICES symlink created" {
    [ -L "/run/headunit/active_services" ]
    [ -e "/run/headunit/active_services" ]
}

@test "Linker: Selected versions are compatible (sanity check)" {
    # Простая проверка, что мы не ссылаемся в пустоту
    run readlink -f /run/headunit/active_app
    [ "$status" -eq 0 ]

    run readlink -f /run/headunit/active_services
    [ "$status" -eq 0 ]
}
