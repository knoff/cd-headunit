<#
.SYNOPSIS
    Утилита сборки HeadUnit OS.

.DESCRIPTION
    Управляет Docker-контейнером сборки, версионированием и переключением веток.

.EXAMPLE
    .\build.ps1                     # Сборка текущей ветки (dev)
    .\build.ps1 -Mode user          # Сборка текущей ветки (user/prod)
    .\build.ps1 -ListTags           # Показать список доступных версий
    .\build.ps1 -Checkout v0.1.0    # Собрать конкретную версию (переключиться и вернуться)
#>
param(
    [string]$InputImage = "2025-11-24-raspios-trixie-arm64-lite.img",
    [string]$Mode = "dev",
    [string]$Checkout = $null,  # Версия для сборки (git tag)
    [switch]$ListTags,          # Просто показать теги
    [switch]$Interactive        # Войти в контейнер
)

$ErrorActionPreference = "Stop"
$ImageName = "headunit-builder"

# === ФУНКЦИИ ===

function Get-GitVersion {
    try {
        # dirty добавляет суффикс, если есть незакоммиченные изменения
        return git describe --tags --always --dirty
    } catch {
        return "unknown-$(Get-Date -Format 'yyyyMMdd')"
    }
}

function Assert-GitClean {
    $status = git status --porcelain
    if ($status) {
        Write-Warning "!!! ВНИМАНИЕ !!!"
        Write-Warning "У вас есть незакоммиченные изменения."
        Write-Warning "Переключение версий невозможно в 'грязном' репозитории."
        Write-Warning "Пожалуйста, закоммитьте (commit) или отложите (stash) изменения."
        throw "Git working directory is dirty."
    }
}

# === 1. РЕЖИМ СПИСКА ВЕРСИЙ ===
if ($ListTags) {
    Write-Host "Доступные версии (Git Tags):" -ForegroundColor Cyan
    git tag -l | Sort-Object -Descending
    exit 0
}

# === 2. ПОДГОТОВКА (ПЕРЕКЛЮЧЕНИЕ ВЕРСИИ) ===
$OriginalBranch = $null
$BuildVersion = $null

if ($Checkout) {
    # Если просят собрать конкретную версию, мы должны быть осторожны
    Assert-GitClean

    # Запоминаем текущую ветку/хеш
    $OriginalBranch = git branch --show-current
    if (-not $OriginalBranch) {
        $OriginalBranch = git rev-parse HEAD
    }

    Write-Host ">>> Switching to version: $Checkout..." -ForegroundColor Yellow
    git checkout $Checkout
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# Блок try/finally гарантирует, что мы вернемся на исходную ветку
try {
    # === 3. ИНИЦИАЛИЗАЦИЯ ===
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $BuildVersion = Get-GitVersion

    # Формируем красивое имя файла: headunit-v0.1.0-user.img
    # Заменяем запрещенные символы в версии на подчеркивание
    $SafeVersion = $BuildVersion -replace '[\\/:\*\?"<>\|]', '_'
    $TargetFileName = "headunit-${SafeVersion}-${Mode}.img"

    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " HeadUnit OS Builder" -ForegroundColor Cyan
    Write-Host "=========================================="
    Write-Host " Version:  $BuildVersion" -ForegroundColor Green
    Write-Host " Mode:     $Mode" -ForegroundColor Yellow
    Write-Host " Output:   $TargetFileName" -ForegroundColor Magenta
    Write-Host "=========================================="

    # === 4. ПРОВЕРКИ ===
    if (-not (Test-Path $InputImage)) {
        Write-Warning "Файл '$InputImage' не найден. Сборка упадет."
    }

    # === 5. DOCKER BUILD ===
    Write-Host "`n>>> [1/2] Building Docker environment..." -ForegroundColor Cyan
    docker build -t $ImageName -f builder/Dockerfile .
    if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }

    # === 6. ЗАПУСК СБОРКИ ===
    Write-Host "`n>>> [2/2] Starting Build Container..." -ForegroundColor Cyan

    $DockerArgs = @(
        "--rm",
        "--privileged",
        "-v", "${PWD}:/workspace",
        "-e", "INPUT_IMAGE=$InputImage",
        "-e", "BUILD_VERSION=$BuildVersion",
        "-e", "TARGET_FILENAME=$TargetFileName"  # <-- Передаем имя файла
    )

    if ($Interactive) {
        Write-Host "Entering interactive mode..." -ForegroundColor Yellow
        docker run -it $DockerArgs $ImageName /bin/bash
    } else {
        docker run $DockerArgs $ImageName /bin/bash builder/build.sh $Mode
        if ($LASTEXITCODE -ne 0) { throw "Build script failed" }
    }

    # === 7. ИТОГИ ===
    $StopWatch.Stop()
    Write-Host "`nBuild Successful!" -ForegroundColor Green
    Write-Host "Image: $TargetFileName"
    Write-Host "Time:  $($StopWatch.Elapsed.ToString("mm\:ss"))"

} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    # === 8. ВОЗВРАТ НА ИСХОДНУЮ (Cleanup) ===
    if ($OriginalBranch) {
        Write-Host "`n>>> Restoring original branch: $OriginalBranch..." -ForegroundColor Yellow
        git checkout $OriginalBranch | Out-Null
    }
}
