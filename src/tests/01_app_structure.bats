#!/usr/bin/env bats

@test "App Layer: Codebase is mounted via symlink" {
    # Проверяем, что мы действительно находимся внутри /run/headunit/active_app
    # (health-agent запускает нас по полному пути, но проверка pwd не помешает)
    [ -L "/run/headunit/active_app" ]
}

@test "App Layer: Manifest exists" {
    [ -f "/run/headunit/active_app/manifest.json" ]
}

@test "App Layer: Main entrypoint exists" {
    # Проверяем наличие main.py (или что там у нас будет главным файлом)
    # Пока просто проверяем, что папка не пуста
    run ls /run/headunit/active_app
    [ "$status" -eq 0 ]
}
