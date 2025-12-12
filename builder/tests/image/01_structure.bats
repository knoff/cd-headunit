#!/usr/bin/env bats

setup() {
    if [ -z "$MOUNT_ROOT" ]; then
        echo "Error: MOUNT_ROOT is not set" >&3
        exit 1
    fi
}

@test "Kernel: Boot config (config.txt) exists" {
    # Проверяем путь для новых версий Raspberry Pi OS (Bookworm/Trixie -> /boot/firmware)
    [ -f "$MOUNT_ROOT/boot/firmware/config.txt" ]
}

@test "OS: Version release file exists" {
    # Этот файл мы создаем на этапе 04_sys_config.sh
    [ -f "$MOUNT_ROOT/etc/headunit-release" ]
}

@test "Storage: Data partition mountpoint exists" {
    # Критично для работы OverlayFS
    [ -d "$MOUNT_ROOT/data" ]
}

@test "Infra: Config Library is installed" {
    [ -f "$MOUNT_ROOT/usr/lib/python3/dist-packages/hu_config.py" ]
}

@test "Infra: Health Agent is installed and executable" {
    # Проверяем наличие бинарника (без .py, так как мы его переименовали при копировании)
    [ -f "$MOUNT_ROOT/usr/local/bin/health-agent" ]
}

@test "Infra: Health Agent has execution permissions" {
    [ -x "$MOUNT_ROOT/usr/local/bin/health-agent" ]
}

@test "Infra: Config Wizard is installed" {
    [ -f "$MOUNT_ROOT/usr/local/bin/headunit-config" ]
}


@test "Infra: Runtime tests directory is populated" {
    # Проверяем, что папка есть и она не пустая
    [ -d "$MOUNT_ROOT/opt/headunit/tests/runtime" ]
    run find "$MOUNT_ROOT/opt/headunit/tests/runtime" -name "*.bats"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
