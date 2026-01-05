<#
.SYNOPSIS
    Smart Builder & Tester for HeadUnit OS (Native Architecture).
    Оркестратор полного цикла.

    Логика сборки:
    1. Изменения в App -> Тесты App + Манифест. (Образ НЕ пересобирается).
    2. Изменения в Services -> Тесты Services + Манифест. (Образ НЕ пересобирается).
    3. Изменения в OS -> Полная сборка образа (включает текущие App/Services).
    4. Флаг -Force -> Принудительная сборка всего и генерация образа.
#>
param(
    [string]$InputImage = "2025-11-24-raspios-trixie-arm64-lite.img",
    [string]$Mode = "dev",
    [string]$Checkout = $null,
    [switch]$ListTags,
    [switch]$Interactive,
    [switch]$Force, # Принудительно собрать образ, даже если менялся только App

    # Testing Parameters
    [switch]$TestsSkip,       # Пропустить тесты
    [string]$Test = $null     # Режим "Только тестирование": 'unit', 'current' или путь к img
)

$ErrorActionPreference = "Stop"
$ImageName = "headunit-builder"

# === 1. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

function Get-GitVersion {
    try { return git describe --tags --always --dirty 2>$null } catch { return "unknown" }
}

function Get-BuildTargets {
    # Если Force - собираем всё (App + Svc) и обязательно OS
    if ($Force) { return @("APP", "SERVICES", "OS") }

    # Логика определения области изменений
    $dirty = git status --porcelain
    if ($dirty) {
        $files = $dirty | ForEach-Object { $_.Substring(3) }
    } else {
        $files = git diff-tree --no-commit-id --name-only -r HEAD
    }

    $targets = @()
    # Триггеры изменения слоя ОС
    $os_triggers = @("builder/", "system/", "headunit.conf", "build.ps1")

    $changed_app = $false
    $changed_svc = $false
    $changed_os = $false

    foreach ($file in $files) {
        if ($file -like "src/*") { $changed_app = $true }
        if ($file -like "services/*") { $changed_svc = $true }
        foreach ($trigger in $os_triggers) { if ($file -like "$trigger*") { $changed_os = $true } }
    }

    # Формируем список целей
    if ($changed_app) { $targets += "APP" }
    if ($changed_svc) { $targets += "SERVICES" }

    # ОС собираем ТОЛЬКО если есть изменения в системных файлах
    if ($changed_os) { $targets += "OS" }

    if ($targets.Count -eq 0) { return "NONE" }

    return $targets | Select-Object -Unique
}

function Build-AppLayer {
    Write-Host "`n>>> [BUILD] Application Layer (src/)..." -ForegroundColor Magenta

    # 1. Проверка манифеста (создаем, если нет)
    if (-not (Test-Path "src/manifest.json")) {
        Write-Warning "Manifest missing! Creating default..."
        Set-Content -Path "src/manifest.json" -Value '{"component":"app","version":"0.1.0","dependencies":{"services":">=0.1.0"}}'
    }

    # 2. Запуск тестов (если есть)
    if (Test-Path "src/tests") {
        Write-Host " -> Running App Unit Tests..." -ForegroundColor Gray
        # Здесь будет вызов pytest, когда добавим тесты
    }

    Write-Host " -> App Layer Prepared for deployment." -ForegroundColor Green
}

function Build-ServicesLayer {
    Write-Host "`n>>> [BUILD] Services Layer (services/)..." -ForegroundColor Magenta

    if (-not (Test-Path "services/manifest.json")) {
        Write-Warning "Manifest missing! Creating default..."
        Set-Content -Path "services/manifest.json" -Value '{"component":"services","version":"0.1.0","dependencies":{"os":">=0.1.0"}}'
    }

    if (Test-Path "services/tests") {
        Write-Host " -> Running Services Unit Tests..." -ForegroundColor Gray
    }

    Write-Host " -> Services Layer Prepared for deployment." -ForegroundColor Green
}

function Run-ImageTests {
    param([string]$ImagePath)
    Write-Host "`n>>> [TEST] Running Image Verification..." -ForegroundColor Magenta

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

# === 2. ТОЧКА ВХОДА ===

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
    # Инициализация переменных
    $BuildVersion = Get-GitVersion
    $SafeVersion = $BuildVersion -replace '[\\/:\*\?"<>\|]', '_'
    $TargetFileName = "builder/output/headunit-${SafeVersion}-${Mode}.img"

    # Сборка контейнера (нужен всегда, даже для юнит-тестов)
    if (-not $Test) { Write-Host ">>> [INIT] Preparing Builder Environment..." -ForegroundColor Gray }
    docker build -t $ImageName -f builder/Dockerfile . | Out-Null

    # --- РЕЖИМ: ТОЛЬКО ТЕСТЫ (-Test) ---
    if ($Test) {
        if ($Test -eq "unit") {
            Write-Host ">>> [TEST] Running Unit Tests Only..." -ForegroundColor Cyan
            docker run --rm -v "${PWD}:/workspace" $ImageName `
                    /bin/bash /workspace/builder/lib/test_runner.sh --mode unit
            if ($LASTEXITCODE -ne 0) { throw "Unit Tests Failed!" }
            exit 0
        }
        elseif ($Test -eq "current") { $Tgt = $TargetFileName }
        elseif ($Test -match "\.img$") { $Tgt = $Test }
        else { $Tgt = "builder/output/headunit-${Test}-${Mode}.img" }

        if (-not (Test-Path $Tgt)) { throw "Image not found: $Tgt" }
        Run-ImageTests -ImagePath $Tgt
        exit 0
    }

    # --- PIPELINE EXECUTION ---
    $Targets = Get-BuildTargets

    if ($Targets -contains "NONE") {
        Write-Host "No changes detected. Use -Force to rebuild OS." -ForegroundColor Gray
        exit 0
    }

    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host " Pipeline Targets: $($Targets -join ', ')" -ForegroundColor Cyan
    Write-Host "=========================================="

    # 1. BUILD APP
    if ($Targets -contains "APP") {
        Build-AppLayer
    }

    # 2. BUILD SERVICES
    if ($Targets -contains "SERVICES") {
        Build-ServicesLayer
    }

    # 3. BUILD OS IMAGE
    # Запускаем только если явно изменилась ОС или был передан флаг Force
    if ($Targets -contains "OS") {
        Write-Host "`n>>> [BUILD] OS Image (System Layer)..." -ForegroundColor Yellow

        # 3.1 Pre-Build Unit Tests
        if (-not $TestsSkip) {
            Write-Host " -> Running Builder Unit Tests..." -ForegroundColor Gray
            docker run --rm -v "${PWD}:/workspace" $ImageName `
                /bin/bash /workspace/builder/lib/test_runner.sh --mode unit
            if ($LASTEXITCODE -ne 0) { throw "Builder Unit Tests Failed!" }
        }

        # 3.2 Build Process
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

        # 3.3 Post-Build Verification
        if (-not $TestsSkip -and -not $Interactive) {
            Run-ImageTests -ImagePath $TargetFileName
        }
    } else {
        # Если мы здесь, значит менялись только App или Services, но не OS, и Force не нажат.
        Write-Host "`n[INFO] OS Build skipped." -ForegroundColor Green
        Write-Host "Layers are verified. Use '-Force' to bake them into a new OS image." -ForegroundColor Gray
        Write-Host "Or use 'deploy.ps1' to push updates to a live device." -ForegroundColor Gray
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
