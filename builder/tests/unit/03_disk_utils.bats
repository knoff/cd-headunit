#!/usr/bin/env bats

load "../../lib/utils.sh"
load "../../lib/disk_utils.sh"

# --- MOCKS (Заглушки системных команд) ---

# Переопределяем mkdir, чтобы он не создавал папки
mkdir() {
    echo "CMD: mkdir $*"
}

# Переопределяем mount
mount() {
    echo "CMD: mount $*"
}

# Переопределяем umount
umount() {
    echo "CMD: umount $*"
}

# Переопределяем mountpoint
# Управляем поведением через переменную MOCK_IS_MOUNTED
mountpoint() {
    if [ "$MOCK_IS_MOUNTED" == "true" ]; then
        return 0
    else
        return 1
    fi
}
# ----------------------------------------

@test "DiskUtils: mount_safe creates dir and mounts" {
    run mount_safe "/dev/sda1" "/mnt/target"

    [ "$status" -eq 0 ]
    # Проверяем порядок вызовов
    [[ "${lines[0]}" == "CMD: mkdir -p /mnt/target" ]]
    [[ "${lines[1]}" == "CMD: mount /dev/sda1 /mnt/target" ]]
}

@test "DiskUtils: mount_safe passes extra arguments" {
    run mount_safe "/dev/sda1" "/mnt/target" "-o" "ro"

    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == "CMD: mount -o ro /dev/sda1 /mnt/target" ]]
}

@test "DiskUtils: mount_bind uses --bind" {
    run mount_bind "/source" "/target"

    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "CMD: mkdir -p /target" ]]
    [[ "${lines[1]}" == "CMD: mount --bind /source /target" ]]
}

@test "DiskUtils: umount_safe unmounts if mounted" {
    export MOCK_IS_MOUNTED="true"

    run umount_safe "/mnt/target"

    [ "$status" -eq 0 ]
    [[ "$output" == "CMD: umount /mnt/target" ]]
}

@test "DiskUtils: umount_safe does nothing if not mounted" {
    export MOCK_IS_MOUNTED="false"

    run umount_safe "/mnt/target"

    [ "$status" -eq 0 ]
    [ "$output" == "" ]
}
