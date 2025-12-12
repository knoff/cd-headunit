#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "Network: Interface persistence rules exist" {
    [ -f "$MOUNT_ROOT/etc/udev/rules.d/70-persistent-net.rules" ]
}

@test "Network: Static WiFi Client config exists" {
    [ -f "$MOUNT_ROOT/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection" ]
}

@test "Network: Static WiFi AP config exists" {
    [ -f "$MOUNT_ROOT/etc/NetworkManager/system-connections/internal-ap.nmconnection" ]
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

@test "Network: Identity Service is installed but DISABLED" {
    [ -f "$MOUNT_ROOT/etc/systemd/system/headunit-identity.service" ]
    [ ! -L "$MOUNT_ROOT/etc/systemd/system/multi-user.target.wants/headunit-identity.service" ]
}

@test "Network: RFKill unblock service enabled" {
    [ -L "$MOUNT_ROOT/etc/systemd/system/multi-user.target.wants/rfkill-unblock.service" ]
}
