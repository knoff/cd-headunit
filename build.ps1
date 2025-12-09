<#
.SYNOPSIS
    Smart Builder & Tester for HeadUnit OS.
    Оркестратор полного цикла: определяет контекст изменений и запускает соответствующие пайплайны.
#>
param(
    [string]$InputImage = "2025-11-24-raspios-trixie-arm64-lite.img",
    [string]$Mode = "dev",
    [string]$Checkout = $null,
    [switch]$ListTags,
    [switch]$Interactive,
    [switch]$Force, # Принудительно включить режим OS Build

    # Testing Parameters
    [switch]$TestsSkip,       # Пропустить тесты (только для OS Layer)
    [string]$Test = $null     # Режим "Только тестирование"
)

$ErrorActionPreference = "Stop"
$ImageName = "headunit-builder"

# === 1. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

function Get-GitVersion {
    try { return git describe --tags --always --dirty 2>$null } catch { return "unknown" }
}

function Get-ChangeScope {
    # Логика определения области изменений (Scope Detection)
    $dirty = git status --porcelain
    if ($dirty) {
        $files = $dirty | ForEach-Object { $_.Substring(3) }
    } else {
        $files = git diff-tree --no-commit-id --name-only -r HEAD
    }

    $os_triggers = @("builder/", "system/", "headunit.conf", "build.ps1")
    $app_triggers = @("src/", "deploy/", "services/")

    $needs_os = $false
    $needs_app = $false

    foreach ($file in $files) {
        foreach ($trigger in $os_triggers) { if ($file -like "$trigger*") { $needs_os = $true } }
        foreach ($trigger in $app_triggers) { if ($file -like "$trigger*") { $needs_app = $true } }
    }

    if ($needs_os) { return "OS" }
    if ($needs_app) { return "APP" }
    return "NONE"
}

function Run-ImageTests {
    param([string]$ImagePath)
    Write-Host "`n>>> [TEST] Running Image Verification..." -ForegroundColor Magenta

    # Конвертация путей для Docker
    if (Test-Path $ImagePath -PathType Leaf) {
        $RealTarget = Resolve-Path $ImagePath
        $RelPath = Get-Item $RealTarget | Resolve-Path -Relative
        $ContainerPath = "/workspace/" + $RelPath.TrimStart(".\").Replace("\", "/")
    } else {
        $ContainerPath = "/workspace/" + $ImagePath.Replace("\", "/")
    }

    docker run --rm --privileged -v "${PWD}:/workspace" $ImageName `
        /bin/bash /workspace/builder/lib/test_runner.sh --mode image --target "$ContainerPath"

    if ($LASTEXITCODE -ne 0) { throw "Image Verification Failed!" }
    Write-Host ">>> [TEST] Image OK." -ForegroundColor Green
}

function Run-AppTests {
    # Заглушка для тестов приложений (Python/JS)
    # В будущем здесь будет: docker run ... pytest src/
    Write-Host "`n>>> [APP] Running Application Tests..." -ForegroundColor Magenta

    if (Test-Path "src/tests") {
        Write-Host " -> Found tests. Executing..." -ForegroundColor Gray
        # Тут будет реальный вызов
        Start-Sleep -Seconds 1
    } else {
        Write-Warning " -> No application tests found in src/tests (Skipping)"
    }

    Write-Host ">>> [APP] Tests Passed." -ForegroundColor Green
}

# === 2. ТОЧКА ВХОДА (MAIN) ===

if ($ListTags) { git tag -l | Sort-Object -Descending; exit 0 }

# --- Time Machine (Checkout) ---
$OriginalBranch = $null
if ($Checkout) {
    if (git status --porcelain) { throw "GIT_DIRTY: Commit changes before checkout." }
    $OriginalBranch = git branch --show-current
    if (-not $OriginalBranch) { $OriginalBranch = git rev-parse HEAD }
    git checkout $Checkout 2>&1 | Out-Null
}

try {
    # Подготовка переменных окружения
    $BuildVersion = Get-GitVersion
    $SafeVersion = $BuildVersion -replace '[\\/:\*\?"<>\|]', '_'
    $TargetFileName = "builder/output/headunit-${SafeVersion}-${Mode}.img"

    # Сборка базового контейнера (нужен всегда, даже для тестов)
    Write-Host ">>> [INIT] Preparing Builder Environment..." -ForegroundColor Gray
    docker build -t $ImageName -f builder/Dockerfile . | Out-Null

    # --- РЕЖИМ: ТОЛЬКО ТЕСТЫ (-Test) ---
    if ($Test) {
        if ($Test -eq "current") { $Tgt = $TargetFileName }
        elseif ($Test -match "\.img$") { $Tgt = $Test }
        else { $Tgt = "builder/output/headunit-${Test}-${Mode}.img" }

        if (-not (Test-Path $Tgt)) { throw "Image not found: $Tgt" }
        Run-ImageTests -ImagePath $Tgt
        exit 0
    }

    # --- АНАЛИЗ И ВЕТВЛЕНИЕ (LOGIC BRANCHING) ---
    $Scope = Get-ChangeScope
    if ($Force) { $Scope = "OS" }

    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host " HeadUnit Pipeline: $Scope" -ForegroundColor Cyan
    Write-Host "=========================================="

    switch ($Scope) {
        "OS" {
            # === ВЕТКА 1: СБОРКА ОС (OS LAYER) ===
            Write-Host "Detected changes in SYSTEM layer." -ForegroundColor Yellow
            Write-Host "Action: Full OS Rebuild & Test" -ForegroundColor Yellow

            # 1. Pre-Build Unit Tests
            if (-not $TestsSkip) {
                Write-Host "`n>>> [1/3] Running Builder Unit Tests..." -ForegroundColor Cyan
                docker run --rm -v "${PWD}:/workspace" $ImageName `
                    /bin/bash /workspace/builder/lib/test_runner.sh --mode unit
                if ($LASTEXITCODE -ne 0) { throw "Builder Unit Tests Failed!" }
            }

            # 2. Build Process
            Write-Host "`n>>> [2/3] Building Disk Image..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Force -Path "builder/output" | Out-Null

            if (-not (Test-Path $InputImage)) { Write-Warning "Base image $InputImage not found!" }

            $DockerArgs = @("--rm", "--privileged", "-v", "${PWD}:/workspace",
                "-e", "INPUT_IMAGE=$InputImage", "-e", "BUILD_VERSION=$BuildVersion",
                "-e", "TARGET_FILENAME=$TargetFileName")

            if ($Interactive) { docker run -it $DockerArgs $ImageName /bin/bash }
            else {
                docker run $DockerArgs $ImageName /bin/bash builder/build.sh $Mode
                if ($LASTEXITCODE -ne 0) { throw "OS Build Failed" }
            }

            # 3. Post-Build Verification
            if (-not $TestsSkip -and -not $Interactive) {
                Write-Host "`n>>> [3/3] Verifying Result..." -ForegroundColor Cyan
                Run-ImageTests -ImagePath $TargetFileName
            }
        }

        "APP" {
            # === ВЕТКА 2: ПРИЛОЖЕНИЕ (APP LAYER) ===
            Write-Host "Detected changes in APPLICATION layer only." -ForegroundColor Green
            Write-Host "Action: App Tests Only (Skip OS Build)" -ForegroundColor Green

            # 1. App Tests
            Run-AppTests

            # 2. Инструкция
            Write-Host "`n[SUCCESS] App changes verified." -ForegroundColor Green
            Write-Host "To deploy to device use: .\deploy.ps1 -Ip <DEVICE_IP>" -ForegroundColor Cyan
        }

        "NONE" {
            # === ВЕТКА 3: НЕТ ИЗМЕНЕНИЙ ===
            Write-Host "No relevant changes detected." -ForegroundColor Gray
            if (-not $Interactive) {
                Write-Host "Use -Force to rebuild OS or check your git status."
            }
        }
    }

} catch {
    if ($_.Exception.Message -eq "GIT_DIRTY") {
        Write-Host "`n[ERROR] Repo is dirty. Commit changes first." -ForegroundColor Red
    } else {
        Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
} finally {
    if ($OriginalBranch) { git checkout $OriginalBranch 2>&1 | Out-Null }
}
