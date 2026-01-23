#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "User: cdreborn exists" {
    # Check /etc/passwd inside the image
    run grep "^cdreborn:" "$MOUNT_ROOT/etc/passwd"
    [ "$status" -eq 0 ]
}

@test "User: Groups Check" {
    # Check /etc/group inside the image
    # Note: grep format depends on how many users are in the group, ensuring cdreborn is present
    run grep "^adm:.*cdreborn" "$MOUNT_ROOT/etc/group"
    [ "$status" -eq 0 ]

    run grep "^systemd-journal:.*cdreborn" "$MOUNT_ROOT/etc/group"
    [ "$status" -eq 0 ]

    run grep "^sudo:.*cdreborn" "$MOUNT_ROOT/etc/group"
    [ "$status" -eq 0 ]
}

@test "Sudoers: Config File Exists" {
    [ -f "$MOUNT_ROOT/etc/sudoers.d/010_headunit-admin" ]

    run stat -c "%a" "$MOUNT_ROOT/etc/sudoers.d/010_headunit-admin"
    [ "$output" -eq "440" ]
}

@test "Data: Ownership (Mount Point)" {
    # Checks the ownership of the directory structure on the rootfs.
    # Note: This might not reflect the actual Data Partition if not mounted,
    # but verify the intention of 04_sys_config.sh

    [ -d "$MOUNT_ROOT/data/incoming_updates" ]

    # We check UID/User name. Since we are in docker, 'cdreborn' user might not exist
    # in the context of 'stat' unless we rely on numeric IDs or if chroot/passwd is looked up.
    # 'stat -c %U' tries to resolve UID to name using /etc/passwd of the HOST (Container).
    # Since Docker container doesn't have cdreborn, it might return the ID or 'UNKNOWN'.

    # Better approach: Check numeric ID matching what we created.
    # 1. Get UID of cdreborn from image
    CDREBORN_ID=$(grep "^cdreborn:" "$MOUNT_ROOT/etc/passwd" | cut -d: -f3)
    [ -n "$CDREBORN_ID" ]

    # 2. Check ownership of directory
    run stat -c "%u" "$MOUNT_ROOT/data/incoming_updates"
    [ "$output" -eq "$CDREBORN_ID" ]
}
