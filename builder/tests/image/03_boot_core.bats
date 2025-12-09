#!/usr/bin/env bats

setup() {
    [ -n "$MOUNT_ROOT" ] || exit 1
}

@test "Boot: Config.txt enables Initramfs (Required for OverlayFS)" {
    # Без этой строки оверлей не загрузится
    run grep "initramfs initramfs8 followkernel" "$MOUNT_ROOT/boot/firmware/config.txt"
    [ "$status" -eq 0 ]
}

@test "Boot: Cmdline sets correct RootFS mode" {
    # Мы убирали 'ro' и добавляли 'fsck.mode=skip'
    local cmdline="$MOUNT_ROOT/boot/firmware/cmdline.txt"

    # Проверка негативная: не должно быть ro
    run grep -v " ro " "$cmdline"
    [ "$status" -eq 0 ]

    # Проверка позитивная
    run grep "fsck.mode=skip" "$cmdline"
    [ "$status" -eq 0 ]
}

@test "Boot: Fstab contains Data partition" {
    run grep "/data" "$MOUNT_ROOT/etc/fstab"
    [ "$status" -eq 0 ]
}

@test "Boot: Fstab mounts Root as RW defaults (Logic check)" {
    # OverlayFS требует, чтобы fstab не пытался ремаунтить корень в RO
    # Ищем строку с "/" (корень) и проверяем, что там нет "ro,"
    # Это грубая проверка, но для начала пойдет
    run grep "[[:space:]]/[[:space:]]" "$MOUNT_ROOT/etc/fstab"
    [ "$status" -eq 0 ]
    [[ "$output" != *"ro,"* ]]
}
