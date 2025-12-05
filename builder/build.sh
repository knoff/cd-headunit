#!/bin/bash
set -e

# ==========================================
# HEADUNIT BUILDER (DOCKER ENTRYPOINT)
# ==========================================

# 1. Фиксация рабочей директории
# В Docker мы обычно в /workspace, но скрипт лежит в /workspace/builder
# Переходим в папку builder, чтобы относительные пути (lib/, stages/) работали корректно
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$BUILD_DIR")"

cleanup_on_exit() {
    # Если скрипт 99 существует, запускаем его
    if [ -f "stages/99_cleanup.sh" ]; then
        source "stages/99_cleanup.sh"
    fi
}
trap cleanup_on_exit EXIT

cd "$BUILD_DIR"

# 2. Подключение библиотек
# Проверяем наличие, чтобы не упасть с непонятной ошибкой
if [ -f "lib/utils.sh" ]; then source lib/utils.sh; else echo "Error: lib/utils.sh not found"; exit 1; fi
if [ -f "lib/config_parser.sh" ]; then source lib/config_parser.sh; else die "lib/config_parser.sh not found"; fi
if [ -f "lib/disk_utils.sh" ]; then source lib/disk_utils.sh; else die "lib/disk_utils.sh not found"; fi

# 3. Проверка прав (внутри Docker должно быть root)
if [ "$(id -u)" -ne 0 ]; then
   die "Build must run as root (ensure Docker runs with --privileged)"
fi

# 4. Инициализация конфигурации
# Аргумент 1 передается из CMD докера или вручную (default: dev)
export BUILD_MODE="${1:-dev}"

log_info "=========================================="
log_info " HeadUnit OS Builder"
log_info " Mode: $BUILD_MODE"
log_info " Context: Docker Container"
log_info "=========================================="

# Загружаем конфиг (headunit.conf лежит рядом с build.sh)
load_config "$BUILD_MODE"

# 5. Автоматический запуск этапов (Stages Runner)
# Ищем все .sh файлы в папке stages, сортируем и запускаем
log_info "Scanning stages..."

# Включаем nullglob, чтобы если файлов нет, цикл не запускался с литералом "*"
shopt -s nullglob
FILES=(stages/*.sh)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    die "No build stages found in $BUILD_DIR/stages/"
fi

for stage_script in "${FILES[@]}"; do
    stage_name=$(basename "$stage_script")

    # Пропускаем cleanup в основном цикле, так как он вызывается через trap
    if [ "$stage_name" == "99_cleanup.sh" ]; then
        continue
    fi

    echo ""
    log_step "Executing Stage: $stage_name"

    # Запускаем скрипт в текущем shell, чтобы сохранить переменные (LOOP_DST и т.д.)
    source "$stage_script"
done

# 6. Финализация (если всё прошло успешно)
echo ""
log_info "=========================================="
log_info " Build Cycle Complete!"
log_info " Image: ${IMAGE_NAME}.img"
log_info "=========================================="
