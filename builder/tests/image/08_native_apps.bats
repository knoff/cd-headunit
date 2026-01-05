#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "Native Apps: Linker script is installed" {
    [ -f "$MOUNT_ROOT/usr/local/bin/headunit-boot-linker" ]
    [ -x "$MOUNT_ROOT/usr/local/bin/headunit-boot-linker" ]
}

@test "Native Apps: Linker service is enabled (sysinit target)" {
    # Мы вешали его на sysinit.target, проверяем симлинк там
    local link="$MOUNT_ROOT/etc/systemd/system/sysinit.target.wants/headunit-boot-linker.service"
    [ -L "$link" ]
}

@test "Native Apps: Factory APP directory exists" {
    [ -d "$MOUNT_ROOT/opt/headunit/factory/app" ]
    # Проверяем наличие манифеста (мы его создаем в 04_sys_config.sh если нет)
    [ -f "$MOUNT_ROOT/opt/headunit/factory/app/manifest.json" ]
}

@test "Native Apps: Factory SERVICES directory exists" {
    [ -d "$MOUNT_ROOT/opt/headunit/factory/services" ]
    [ -f "$MOUNT_ROOT/opt/headunit/factory/services/manifest.json" ]
}

@test "Native Apps: Release file contains component versions" {
    # Проверяем, что в /etc/headunit-release добавились новые поля
    run grep "FACTORY_APP_VERSION=" "$MOUNT_ROOT/etc/headunit-release"
    [ "$status" -eq 0 ]

    run grep "FACTORY_SERVICES_VERSION=" "$MOUNT_ROOT/etc/headunit-release"
    [ "$status" -eq 0 ]
}
