<#
.SYNOPSIS
    Запускает сборку образа Headunit в Docker-контейнере.
    Использование:
    .\build.ps1                  # Сборка dev по умолчанию
    .\build.ps1 -Mode user       # Сборка user (продакшен)
    .\build.ps1 -Interactive     # Вход в консоль контейнера
#>
param(
    [string]$InputImage = "2025-11-24-raspios-trixie-arm64-lite.img",
    [string]$Mode = "dev",
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"
$ImageName = "headunit-builder"

# 1. Проверяем наличие базового образа
if (-not (Test-Path $InputImage)) {
    Write-Warning "Файл '$InputImage' не найден в корне. Сборка упадет на этапе копирования."
}

# 2. Собираем Docker-образ билдера
Write-Host ">>> Building Docker environment..." -ForegroundColor Cyan
docker build -t $ImageName -f builder/Dockerfile .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 3. Формируем аргументы запуска Docker
# --privileged нужен для losetup и mount
$DockerArgs = @(
    "--rm",
    "--privileged",
    "-v", "${PWD}:/workspace",
    "-e", "INPUT_IMAGE=$InputImage"
)

Write-Host ">>> Starting Container..." -ForegroundColor Cyan

if ($Interactive) {
    # Режим отладки: просто запускаем bash (CMD из Dockerfile сработает или переопределяем)
    Write-Host "Entering interactive mode..." -ForegroundColor Yellow
    docker run -it $DockerArgs $ImageName /bin/bash
} else {
    # Режим сборки: ЯВНО запускаем build.sh
    Write-Host "Running Build in [$Mode] mode..." -ForegroundColor Green
    # Обратите внимание: мы явно указываем путь к скрипту и передаем Mode как аргумент
    docker run $DockerArgs $ImageName /bin/bash builder/build.sh $Mode
}
