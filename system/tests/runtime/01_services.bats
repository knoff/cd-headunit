#!/usr/bin/env bats

@test "Core: D-Bus service is active" {
    run systemctl is-active dbus
    [ "$status" -eq 0 ]
    [ "$output" = "active" ]
}

@test "Network: NetworkManager is active" {
    run systemctl is-active NetworkManager
    [ "$status" -eq 0 ]
}

@test "Hardware: RFKill Unblock service is active" {
    run systemctl is-active rfkill-unblock
    [ "$status" -eq 0 ]
}

# Пример теста, который упадет информативно, если сервиса нет
@test "Container: Docker is active" {
    # skip "Docker is optional for now"  <-- можно пропускать тесты
    run systemctl is-active docker
    [ "$status" -eq 0 ]
}
