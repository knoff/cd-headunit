#!/bin/bash
# STAGE 99: Cleanup

log_step "Cleanup"

# Размонтируем все, что могло остаться
umount_safe /mnt/dst/sys
umount_safe /mnt/dst/proc
umount_safe /mnt/dst/dev/pts
umount_safe /mnt/dst/dev

umount_safe /mnt/dst/boot/firmware
umount_safe /mnt/dst

umount_safe /mnt/src/boot/firmware
umount_safe /mnt/src

# Отключаем Loop devices
if [ -n "$LOOP_DST" ]; then
    losetup -d "$LOOP_DST" 2>/dev/null || true
    log_info "Detached Target: $LOOP_DST"
fi

if [ -n "$LOOP_SRC" ]; then
    losetup -d "$LOOP_SRC" 2>/dev/null || true
    log_info "Detached Source: $LOOP_SRC"
fi
