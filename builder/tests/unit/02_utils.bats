#!/usr/bin/env bats

load "../../lib/utils.sh"

@test "Utils: log_info prints with [INFO] prefix" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "Utils: log_warn prints with [WARN] prefix" {
    run log_warn "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
}

@test "Utils: log_error prints with [ERROR] prefix" {
    run log_error "error message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
}

@test "Utils: die logs error and exits with 1" {
    # Запускаем в subshell, так как die вызывает exit
    run die "fatal error"
    [ "$status" -eq 1 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"fatal error"* ]]
}
