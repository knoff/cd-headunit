#!/bin/bash

refresh_partitions() {
    local loopdev="$1"
    log_info "Refreshing partitions on $loopdev..."
    partprobe "$loopdev" || true
    sleep 1

    local loopname=$(basename "$loopdev")
    for part_dir in /sys/class/block/${loopname}p*; do
        if [ -d "$part_dir" ]; then
            local partname=$(basename "$part_dir")
            local devnode="/dev/$partname"
            if [ ! -b "$devnode" ]; then
                local dev_numerals=$(cat "$part_dir/dev")
                local major=${dev_numerals%%:*}
                local minor=${dev_numerals##*:}
                mknod "$devnode" b "$major" "$minor"
            fi
        fi
    done
}

mount_safe() {
    local dev="$1"
    local mnt="$2"
    shift 2
    mkdir -p "$mnt"
    # $@ позволяет передавать опции, если вдруг понадобятся в будущем
    mount "$@" "$dev" "$mnt"
}

# Новая функция специально для системных папок
mount_bind() {
    local src="$1"
    local dest="$2"
    mkdir -p "$dest"
    mount --bind "$src" "$dest"
}

umount_safe() {
    local mnt="$1"
    if mountpoint -q "$mnt"; then
        umount "$mnt"
    fi
}

# Рекурсивное размонтирование для очистки перед билдом
recursive_umount() {
    local target_dir="$1"
    if [ ! -d "$target_dir" ]; then return; fi

    log_info "Defensive cleanup of $target_dir..."
    # Сортируем точки монтирования по длине в обратном порядке (сначала самые глубокие)
    grep "$target_dir" /proc/mounts | cut -d' ' -f2 | sort -r | while read -r mnt; do
        log_warn "Force unmounting leftover: $mnt"
        umount -l "$mnt" || true
    done
}
