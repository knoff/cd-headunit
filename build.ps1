<#
.SYNOPSIS
    Smart Builder для HeadUnit OS.
    Автоматически определяет тип изменений (OS vs App).
#>
param(
    [string]$InputImage = "2025-11-24-raspios-trixie-arm64-lite.img",
    [string]$Mode = "dev",
    [string]$Checkout = $null,
    [switch]$ListTags,
    [switch]$Interactive,
    [switch]$Force # Принудительная сборка OS, даже если менялся только код
)

$ErrorActionPreference = "Stop"
$ImageName = "headunit-builder"

# === ФУНКЦИИ ===

function Get-GitVersion {
    try { return git describe --tags --always --dirty 2>$null } catch { return "unknown" }
}

function Get-ChangeScope {
    # Получаем список измененных файлов (по сравнению с предыдущим коммитом или текущие изменения)
    # Если есть незакоммиченные, смотрим их. Если нет - смотрим последний коммит.
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

function Assert-GitClean {
    if (git status --porcelain) { throw "GIT_DIRTY" }
}

# === НАЧАЛО РАБОТЫ ===

if ($ListTags) {
    git tag -l | Sort-Object -Descending
    exit 0
}

$OriginalBranch = $null

try {
    # 1. ПЕРЕКЛЮЧЕНИЕ ВЕРСИИ
    if ($Checkout) {
        Assert-GitClean
        $OriginalBranch = git branch --show-current
        if (-not $OriginalBranch) { $OriginalBranch = git rev-parse HEAD }
        git checkout $Checkout 2>&1 | Out-Null
    }

    # 2. АНАЛИЗ ИЗМЕНЕНИЙ
    $Scope = Get-ChangeScope

    if ($Force) { $Scope = "OS" }

    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " HeadUnit Smart Builder" -ForegroundColor Cyan
    Write-Host "=========================================="
    Write-Host " Detected Change Scope: " -NoNewline

    if ($Scope -eq "OS") {
        Write-Host "OS LAYER (System/Builder)" -ForegroundColor Red
        Write-Host " Action: FULL IMAGE REBUILD" -ForegroundColor Yellow
    } elseif ($Scope -eq "APP") {
        Write-Host "APP LAYER (Source/Config)" -ForegroundColor Green
        Write-Host " Action: LIGHTWEIGHT UPDATE" -ForegroundColor Yellow
    } else {
        Write-Host "NONE / UNKNOWN" -ForegroundColor Gray
        if (-not $Interactive) {
            Write-Host "No relevant changes detected. Use -Force to rebuild OS."
            exit 0
        }
    }
    Write-Host "==========================================`n"

    # 3. ВЕТВЛЕНИЕ ЛОГИКИ

    if ($Scope -eq "APP" -and -not $Force -and -not $Interactive) {
        Write-Host ">>> Skipping OS Build (only app changed)." -ForegroundColor Green
        Write-Host "To deploy these changes to a device, use:" -ForegroundColor Cyan
        Write-Host "  .\deploy.ps1 -Ip <DEVICE_IP>" -ForegroundColor White
        Write-Host "`nTo force OS rebuild, use: .\build.ps1 -Force" -ForegroundColor Gray
        exit 0
    }

    # 4. СБОРКА ОБРАЗА (OS LEVEL)
    # Сюда попадаем, если Scope=OS или Force или Interactive

    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $BuildVersion = Get-GitVersion
    $SafeVersion = $BuildVersion -replace '[\\/:\*\?"<>\|]', '_'
    $TargetFileName = "headunit-${SafeVersion}-${Mode}.img"

    if (-not (Test-Path $InputImage)) { Write-Warning "Base image not found!" }

    Write-Host ">>> [1/2] Building Builder Environment..." -ForegroundColor Cyan
    docker build -t $ImageName -f builder/Dockerfile . | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }

    Write-Host ">>> [2/2] Running OS Build Pipeline..." -ForegroundColor Cyan
    $DockerArgs = @(
        "--rm", "--privileged", "-v", "${PWD}:/workspace",
        "-e", "INPUT_IMAGE=$InputImage",
        "-e", "BUILD_VERSION=$BuildVersion",
        "-e", "TARGET_FILENAME=$TargetFileName"
    )

    if ($Interactive) {
        docker run -it $DockerArgs $ImageName /bin/bash
    } else {
        docker run $DockerArgs $ImageName /bin/bash builder/build.sh $Mode
        if ($LASTEXITCODE -ne 0) { throw "Build failed" }
    }

    $StopWatch.Stop()
    Write-Host "`nOS Build Successful: $TargetFileName" -ForegroundColor Green
    Write-Host "Time: $($StopWatch.Elapsed.ToString("mm\:ss"))"

} catch {
    if ($_.Exception.Message -eq "GIT_DIRTY") {
        Write-Host "`n[ERROR] Repo is dirty. Commit changes or stash them." -ForegroundColor Red
    } else {
        Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
} finally {
    if ($OriginalBranch) { git checkout $OriginalBranch 2>&1 | Out-Null }
}
