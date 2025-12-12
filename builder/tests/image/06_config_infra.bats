#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "Config Infra: Python shared library (hu_config) is installed" {
    # Проверяем наличие библиотеки в dist-packages
    run find "$MOUNT_ROOT/usr/lib/python3/dist-packages/" -name "hu_config.py"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "Config Infra: Configuration scripts are executable" {
    [ -x "$MOUNT_ROOT/usr/local/bin/headunit-config" ]
    [ -x "$MOUNT_ROOT/usr/local/bin/headunit-apply-config" ]
}

@test "Config Infra: Factory Defaults file exists and is valid JSON" {
    local defaults="$MOUNT_ROOT/etc/headunit/factory_defaults.json"
    [ -f "$defaults" ]

    # Простая проверка на наличие ключевого поля "serial" (без jq, чтобы не зависеть от хоста)
    run grep '"serial":' "$defaults"
    [ "$status" -eq 0 ]
}

@test "Config Infra: Factory Defaults permissions are secure (644)" {
    run stat -c %a "$MOUNT_ROOT/etc/headunit/factory_defaults.json"
    [ "$output" -eq 644 ]
}
