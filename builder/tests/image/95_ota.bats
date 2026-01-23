#!/usr/bin/env bats

@test "OTA: Update Agent installed" {
    run ls "$MOUNT_ROOT/usr/local/bin/headunit-update-agent"
    [ "$status" -eq 0 ]

    # Check permissions (executable)
    run stat -c "%a" "$MOUNT_ROOT/usr/local/bin/headunit-update-agent"
    # Expect 755 or similar
    [[ "$output" =~ 755|775 ]]
}

@test "OTA: Systemd Units installed" {
    run ls "$MOUNT_ROOT/etc/systemd/system/headunit-update-monitor.path"
    [ "$status" -eq 0 ]

    run ls "$MOUNT_ROOT/etc/systemd/system/headunit-update-monitor.service"
    [ "$status" -eq 0 ]

    run ls "$MOUNT_ROOT/etc/systemd/system/headunit-update-usb-scan.service"
    [ "$status" -eq 0 ]

    # Monitor path should be enabled
    run ls "$MOUNT_ROOT/etc/systemd/system/multi-user.target.wants/headunit-update-monitor.path"
    [ "$status" -eq 0 ]
}

@test "OTA: Udev Rules installed" {
    run ls "$MOUNT_ROOT/etc/udev/rules.d/99-headunit-update.rules"
    [ "$status" -eq 0 ]
}
