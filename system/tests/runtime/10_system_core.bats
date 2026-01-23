#!/usr/bin/env bats

@test "System: OverlayFS is mounted and active" {
    run mount
    [[ "$output" == *"overlay on / type overlay"* ]]
}

@test "System: ZRAM swap is active" {
    # Проверяем, что модуль загружен и устройство инициализировано
    [ -b "/dev/zram0" ]

    run cat /proc/swaps
    [[ "$output" == *"/dev/zram0"* ]]
}

@test "System: Data partition is writable" {
    # Критически важно: если /data в RO, приложение упадет
    run touch /data/.test_write
    [ "$status" -eq 0 ]
    rm -f /data/.test_write
}

@test "System: Release info matches expectations" {
    [ -f "/etc/headunit-release" ]
    run grep "ID=headunit" "/etc/headunit-release"
    [ "$status" -eq 0 ]
}

@test "System: Python 3.13 is installed" {
    run python3 --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Python 3.13" ]]
}
