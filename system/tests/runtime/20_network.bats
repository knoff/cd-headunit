#!/usr/bin/env bats

@test "Network: Interface wlan0 (AP) exists" {
    run ip link show wlan0
    [ "$status" -eq 0 ]
}


@test "Network: Interface wlan1 (Client) exists" {
    run ip link show wlan1
    [ "$status" -eq 0 ]
}

@test "Network: NetworkManager is running" {
    run systemctl is-active NetworkManager
    [ "$status" -eq 0 ]
}

@test "Network: Hostname is set correctly" {
    # Проверяем, что hostname не дефолтный raspberrypi
    run cat /etc/hostname
    [ "$output" != "raspberrypi" ]
}
