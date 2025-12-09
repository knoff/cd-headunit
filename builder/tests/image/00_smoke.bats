#!/usr/bin/env bats

# setup() запускается перед каждым @test в этом файле
setup() {
    # Проверка, что Test Runner передал нам путь к смонтированному образу
    if [ -z "$MOUNT_ROOT" ]; then
        echo "Error: MOUNT_ROOT environment variable is not set" >&3
        exit 1
    fi
}

@test "Smoke: Mount point root directory exists" {
    [ -d "$MOUNT_ROOT" ]
}

@test "Smoke: Boot directory is accessible" {
    # Проверяем, что внутри образа есть папка boot
    [ -d "$MOUNT_ROOT/boot" ]
}
