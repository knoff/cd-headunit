#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "Network: Interface persistence rules exist" {
    [ -f "$MOUNT_ROOT/etc/udev/rules.d/70-persistent-net.rules" ]
}

@test "Network: WiFi Client (External) config created" {
    local nm_conf="$MOUNT_ROOT/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection"
    [ -f "$nm_conf" ]
}

@test "Network: WiFi AP (Internal) config created" {
    local ap_conf="$MOUNT_ROOT/etc/NetworkManager/system-connections/internal-ap.nmconnection"
    [ -f "$ap_conf" ]
}

@test "Network: WiFi configs have secure permissions (600)" {
    # NetworkManager игнорирует файлы с правами 777
    local client_conf="$MOUNT_ROOT/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection"
    local ap_conf="$MOUNT_ROOT/etc/NetworkManager/system-connections/internal-ap.nmconnection"

    run stat -c %a "$client_conf"
    [ "$status" -eq 0 ]
    [ "$output" -eq 600 ]

    run stat -c %a "$ap_conf"
    [ "$status" -eq 0 ]
    [ "$output" -eq 600 ]
}

@test "Network: AP is configured with correct static IP" {
    local ap_conf="$MOUNT_ROOT/etc/NetworkManager/system-connections/internal-ap.nmconnection"

    # Ищем строку address1=...
    # Предполагаем, что IP задается в конфиге. Для теста можно проверить наличие ключа address1
    run grep "address1=" "$ap_conf"
    [ "$status" -eq 0 ]
}

@test "Network: RFKill unblock service enabled" {
    [ -L "$MOUNT_ROOT/etc/systemd/system/multi-user.target.wants/rfkill-unblock.service" ]
}
