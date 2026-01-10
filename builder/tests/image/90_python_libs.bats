#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "Python Libs: cd-protocol removed from OS layer" {
    # Проверяем, что библиотеки НЕТ в системном dist-packages
    [ ! -d "$MOUNT_ROOT/usr/lib/python3/dist-packages/cd_protocol" ]
}

@test "Python Libs: cd-protocol present in Services layer" {
    # Проверяем, что библиотека ЕСТЬ в Services factory
    [ -d "$MOUNT_ROOT/opt/headunit/factory/services/lib/cd_protocol" ]
    [ -f "$MOUNT_ROOT/opt/headunit/factory/services/lib/cd_protocol/__init__.py" ]
}

@test "Python Libs: .pth file linkage exists" {
    PTH_FILE="$MOUNT_ROOT/usr/lib/python3/dist-packages/headunit-services.pth"

    [ -f "$PTH_FILE" ]

    # Проверяем содержимое
    run cat "$PTH_FILE"
    [ "$status" -eq 0 ]
    [ "$output" = "/run/headunit/active_services/lib" ]
}
