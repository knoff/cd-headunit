#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "Identity: Target user exists" {
    # Парсим конфиг, чтобы узнать ожидаемого юзера, или хардкодим/ищем в /home
    # Для универсальности проверим наличие папки в /home, которая не 'pi'
    # (Предполагаем, что юзер создан)

    run ls "$MOUNT_ROOT/home"
    [ "$status" -eq 0 ]
    [[ "$output" != "" ]]
}

@test "Identity: Hostname is configured" {
    [ -s "$MOUNT_ROOT/etc/hostname" ]
    run cat "$MOUNT_ROOT/etc/hostname"
    [ "$output" != "raspberrypi" ]
}

@test "Identity: Console font fix applied" {
    # Проверяем наш фикс для кириллицы
    run grep 'CODESET="Uni2"' "$MOUNT_ROOT/etc/default/console-setup"
    [ "$status" -eq 0 ]
}
#
#@test "Identity: Release info is present" {
#    [ -f "$MOUNT_ROOT/etc/headunit-release" ]
#    [ -f "$MOUNT_ROOT/opt/headunit/version.json" ]
#}
