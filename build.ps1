<#
.SYNOPSIS
    Запускает сборку образа Headunit в Docker-контейнере.
#>
param(
    [string]$InputImage = "2025-11-24-raspios-trixie-arm64-lite.img",
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"
$ImageName = "headunit-builder"

# 1. Проверяем наличие базового образа (пока просто предупреждаем)
if (-not (Test-Path $InputImage)) {
    Write-Warning "Файл '$InputImage' не найден в корне. Сборка может упасть, если скрипт его ожидает."
}

# 2. Собираем Docker-образ билдера
Write-Host ">>> Building Docker environment..." -ForegroundColor Cyan
docker build -t $ImageName -f builder/Dockerfile .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 3. Запускаем сборку
Write-Host ">>> Starting Build Container..." -ForegroundColor Cyan

# Нам нужен --privileged для loopback mounting и chroot
$DockerArgs = @(
    "--rm",
    "--privileged",
    "-v", "${PWD}:/workspace",
    "-e", "INPUT_IMAGE=$InputImage"
)

if ($Interactive) {
    # Вход в консоль для отладки
    docker run -it $DockerArgs --entrypoint /bin/bash $ImageName
} else {
    # Автоматическая сборка
    docker run $DockerArgs $ImageName
}
