#!/usr/bin/env bats

load "test_helper"

@test "Privileges: Passwordless Sudo is Active" {
    # Проверяем, что можем выполнить sudo без пароля (-n: non-interactive)
    run sudo -n true
    [ "$status" -eq 0 ]
}

@test "Privileges: Mount is Restricted (Passwd Required)" {
    # Skip if running as root (root always has access)
    if [ "$EUID" -eq 0 ]; then
        skip "Test must be run as non-root user"
    fi

    # Clear sudo cache to ensure we test authentication
    sudo -k

    # Проверяем, что mount требует пароль (должен вернуть ошибку с -n)
    run sudo -n mount
    [ "$status" -ne 0 ]
}

@test "Privileges: Journal Access (No Sudo)" {
    # Проверяем чтение логов без sudo
    run journalctl -n 1 --no-pager
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "No journal files were opened" ]]
    [[ ! "$output" =~ "Hint: You are currently not seeing messages" ]]
}

@test "Privileges: Write to /data (User Perms)" {
    TEST_FILE="/data/write_test_$$"
    run touch "$TEST_FILE"
    [ "$status" -eq 0 ]
    rm -f "$TEST_FILE"
}
