#!/usr/bin/env bats

@test "System: CPU info is available" {
    [ -e "/proc/cpuinfo" ]
}

@test "System: User is root (for health checks)" {
    [ "$(whoami)" = "root" ]
}
