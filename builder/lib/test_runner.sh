#!/bin/bash
set -e

# ==========================================
# HEADUNIT TEST RUNNER (BATS EDITION)
# ==========================================

# Относительные пути
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER_DIR="$(dirname "$LIB_DIR")"
TESTS_DIR="$BUILDER_DIR/tests"

source "$LIB_DIR/utils.sh"
source "$LIB_DIR/disk_utils.sh"

MODE=""
TARGET_IMG=""

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode) MODE="$2"; shift ;;
        --target) TARGET_IMG="$2"; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
    shift
done

# Функция проверки наличия BATS
require_bats() {
    if ! command -v bats >/dev/null 2>&1; then
        die "BATS framework not found in builder! Check Dockerfile."
    fi
}

run_unit_tests() {
    log_step "Running UNIT tests (BATS)..."
    require_bats

    # === FIX: Задаем терминал для корректной работы tput в Unit тестах ===
    export TERM=xterm-256color

    # Запускаем тесты кода (если папка существует)
    if [ -d "$TESTS_DIR/unit" ]; then
        # === FIX: Добавлен флаг --pretty ===
        bats --pretty "$TESTS_DIR/unit"
    else
        log_warn "No unit tests found in $TESTS_DIR/unit"
    fi
}

run_image_tests() {
    log_step "Running IMAGE tests (BATS)..."
    require_bats

    if [ -z "$TARGET_IMG" ] || [ ! -f "$TARGET_IMG" ]; then
        die "Target image not found: $TARGET_IMG"
    fi

    local mount_point="/mnt/test_root"
    mkdir -p "$mount_point"

    # 1. Монтирование
    log_info "Mounting $TARGET_IMG for inspection..."
    LOOP_DEV=$(losetup -fP --show "$TARGET_IMG")
    refresh_partitions "$LOOP_DEV"

    # Trap для гарантированной очистки
    cleanup() {
        umount_safe "$mount_point/boot/firmware" || true
        umount_safe "$mount_point/data" || true
        umount_safe "$mount_point" || true
        if [ -n "$LOOP_DEV" ]; then losetup -d "$LOOP_DEV" 2>/dev/null || true; fi
    }
    trap cleanup EXIT

    # Монтируем разделы (Standard Layout)
    mount_safe "${LOOP_DEV}p5" "$mount_point" || die "Failed to mount Rootfs (p5)"
    mount_safe "${LOOP_DEV}p1" "$mount_point/boot/firmware" || die "Failed to mount Boot (p1)"
    # Data раздел не всегда нужен для тестов структуры, но пусть будет
    mount_safe "${LOOP_DEV}p8" "$mount_point/data" || die "Failed to mount Data (p8)"

    # 2. Запуск BATS
    # Экспортируем переменную, чтобы тесты знали, куда смотреть
    export MOUNT_ROOT="$mount_point"
    # === FIX: Задаем терминал для корректной работы tput ===
    export TERM=xterm-256color

    echo "Executing image validation suite..."
    if [ -d "$TESTS_DIR/image" ]; then
        # --pretty делает вывод красивым (галочки)
        bats --pretty "$TESTS_DIR/image"
    else
        log_warn "No image tests found in $TESTS_DIR/image"
    fi
}

case "$MODE" in
    unit)
        run_unit_tests
        ;;
    image)
        run_image_tests
        ;;
    *)
        die "Usage: $0 --mode {unit|image} [--target path]"
        ;;
esac
