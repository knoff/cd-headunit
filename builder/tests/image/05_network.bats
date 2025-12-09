#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "Network: Interface persistence rules exist" {
    [ -f "$MOUNT_ROOT/etc/udev/rules.d/70-persistent-net.rules" ]
}

@test "Network: WiFi client config created" {
    local nm_conf="$MOUNT_ROOT/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection"
    [ -f "$nm_conf" ]
}

@test "Network: WiFi config has secure permissions (600)" {
    # Критично для безопасности! NetworkManager проигнорирует файл с правами 777
    local nm_conf="$MOUNT_ROOT/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection"

    # stat -c %a выводит права в формате 600
    run stat -c %a "$nm_conf"
    [ "$status" -eq 0 ]
    [ "$output" -eq 600 ]
}

@test "Network: RFKill unblock service enabled" {
    # Проверяем симлинк systemd
    [ -L "$MOUNT_ROOT/etc/systemd/system/multi-user.target.wants/rfkill-unblock.service" ]
}
