#!/usr/bin/env bats

# Загружаем общую логику (check_optional)
load "test_helper"

@test "Network [CRITICAL]: AP Interface wlan0 exists" {
    run ip link show wlan0
    [ "$status" -eq 0 ]
}

@test "Network [CRITICAL]: AP Interface wlan0 is UP" {
    run grep "state UP" <(ip link show wlan0)
    [ "$status" -eq 0 ]
}

@test "Network [CRITICAL]: NetworkManager is running" {
    run systemctl is-active NetworkManager
    [ "$status" -eq 0 ]
}

@test "Network [WARN]: Uplink Interface wlan1 is available" {
    check_optional "wlan1 hardware missing" ip link show wlan1
    check_optional "wlan1 exists but is DOWN" grep -q "state UP" <(ip link show wlan1)
}

@test "Network [WARN]: Wired Interface eth0 is available" {
    check_optional "eth0 hardware missing" ip link show eth0
    check_optional "eth0 exists but is DOWN" grep -q "state UP" <(ip link show eth0)
}

@test "Network [WARN]: Internet Connectivity" {
    # Трюк: grep вернет exit code 1, если строки 'default' нет.
    # Это заставит check_optional выдать WARN.
    # sh -c нужен, чтобы bats корректно обработал пайп внутри run.
    check_optional "No default gateway (Offline Mode)" sh -c "ip route show default | grep default"
}
