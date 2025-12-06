<#
.SYNOPSIS
    Запускает сборку образа Headunit в Docker-контейнере.
    Поддерживает версионирование и замер времени.
#>
param(
    [string]$InputImage = "2025-11-24-raspios-trixie-arm64-lite.img",
    [string]$Mode = "dev",
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"
$ImageName = "headunit-builder"

# === 1. ИНИЦИАЛИЗАЦИЯ ТАЙМЕРА ===
$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " HeadUnit OS Builder Launcher" -ForegroundColor Cyan
Write-Host "=========================================="

# === 2. ОПРЕДЕЛЕНИЕ ВЕРСИИ ===
# Пытаемся получить версию из git tags
try {
    $GitVersion = git describe --tags --always --dirty 2>$null
    if (-not $GitVersion) { throw "No version" }
} catch {
    $GitVersion = "dev-$(Get-Date -Format 'yyyyMMdd-HHmm')"
    Write-Warning "Git version detection failed. Using fallback: $GitVersion"
}

Write-Host "Build Version: " -NoNewline; Write-Host "$GitVersion" -ForegroundColor Green
Write-Host "Build Mode:    " -NoNewline; Write-Host "$Mode" -ForegroundColor Yellow

# === 3. ПРОВЕРКИ ===
if (-not (Test-Path $InputImage)) {
    Write-Warning "Файл '$InputImage' не найден. Сборка упадет на этапе копирования."
}

# === 4. СБОРКА DOCKER ОКРУЖЕНИЯ ===
Write-Host "`n>>> [1/2] Building Docker environment..." -ForegroundColor Cyan
docker build -t $ImageName -f builder/Dockerfile .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# === 5. ЗАПУСК СБОРКИ ===
Write-Host "`n>>> [2/2] Starting Build Container..." -ForegroundColor Cyan

# Формируем аргументы
# Передаем BUILD_VERSION внутрь контейнера
$DockerArgs = @(
    "--rm",
    "--privileged",
    "-v", "${PWD}:/workspace",
    "-e", "INPUT_IMAGE=$InputImage",
    "-e", "BUILD_VERSION=$GitVersion"
)

if ($Interactive) {
    Write-Host "Entering interactive mode..." -ForegroundColor Yellow
    docker run -it $DockerArgs $ImageName /bin/bash
} else {
    # Запускаем build.sh с аргументом режима
    docker run $DockerArgs $ImageName /bin/bash builder/build.sh $Mode
}

# === 6. ИТОГИ ===
$StopWatch.Stop()
$TimeSpan = $StopWatch.Elapsed

Write-Host "`n==========================================" -ForegroundColor Cyan
if ($LASTEXITCODE -eq 0) {
    Write-Host " BUILD SUCCESSFUL" -ForegroundColor Green
} else {
    Write-Host " BUILD FAILED" -ForegroundColor Red
}
Write-Host " Total Time:  $($TimeSpan.ToString("mm\:ss\.ff"))"
Write-Host " Version:     $GitVersion"
Write-Host "=========================================="
