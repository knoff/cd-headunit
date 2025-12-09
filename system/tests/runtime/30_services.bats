#!/usr/bin/env bats

@test "Services: D-Bus is active" {
    run systemctl is-active dbus
    [ "$status" -eq 0 ]
}

@test "Services: RFKill Unblock is enabled" {
    # Для Type=oneshot is-active не подходит, проверяем автозагрузку
    run systemctl is-enabled rfkill-unblock
    [ "$status" -eq 0 ]
}

@test "Services: RFKill state is unblocked" {
    # Проверяем реальный эффект работы сервиса
    # Если заблокировано, rfkill list покажет "Soft blocked: yes"
    run rfkill list all
    [[ "$output" != *"Soft blocked: yes"* ]]
}

@test "Services: SSH is enabled (if configured)" {
    # Проверяем SSH, только если он должен быть (можно проверять переменную среды или наличие конфига)
    if [ -f "/etc/ssh/sshd_config" ]; then
        run systemctl is-active ssh
        [ "$status" -eq 0 ]
    else
        skip "SSH not installed"
    fi
}

@test "Services: Docker is ready" {
    # Пока пропускаем, как договаривались
    skip "Docker implementation pending"

    run systemctl is-active docker
    [ "$status" -eq 0 ]
}
