<#
.SYNOPSIS
    OTA Deployment Script for HeadUnit OS.
    Delivers update packages to a running device via SSH.

.DESCRIPTION
    Replaces the old 'deploy.ps1' that used Docker context.
    Now functionality is focused on "Push Update":
    1. Find latest .tar.gz package in builder/output/updates/ (or accept explicit path).
    2. SCP to target device (/data/incoming_updates/).
    3. Monitor progress (optional, via tailing logs or checking status).

.EXAMPLE
    .\deploy.ps1 -Target 192.168.1.100
    Deploy latest available package to device.

.EXAMPLE
    .\deploy.ps1 -Target 10.0.0.5 -File .\builder\output\updates\headunit-services-v0.5.0.tar.gz
    Deploy specific package.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Target, # IP address or Hostname

    [string]$User = "root", # Default user (root for dev, or pi/admin)
    [string]$File,          # Path to .tar.gz package. If empty, finds latest.
    [switch]$Reboot,        # Force reboot after (usually agent handles it)
    [switch]$Log            # Follow logs after push
)

$ErrorActionPreference = "Stop"

# --- HELPERS ---

function Get-LatestUpdate {
    $Dir = "builder/output/updates"
    if (-not (Test-Path $Dir)) { throw "No updates found in $Dir. Run build.ps1 first." }

    $Latest = Get-ChildItem -Path $Dir -Filter "*.tar.gz" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $Latest) { throw "No .tar.gz files found in $Dir." }

    return $Latest.FullName
}

# --- MAIN ---

try {
    Write-Host ">>> [DEPLOY] HeadUnit OTA Updater" -ForegroundColor Cyan

    # 1. Select File
    $PackagePath = $File
    if (-not $PackagePath) {
        Write-Host " -> Searching for latest package..." -ForegroundColor Gray
        $PackagePath = Get-LatestUpdate
    }

    if (-not (Test-Path $PackagePath)) { throw "Package not found: $PackagePath" }

    $PackageName = Split-Path $PackagePath -Leaf
    $ShaFile = "$PackagePath.sha256"

    if (-not (Test-Path $ShaFile)) {
        Write-Warning "Checksum file missing for $PackageName! Agent might reject it."
        # Optional: Generate it on the fly?
        # Get-FileHash ... but format must match linux sha256sum
    }

    Write-Host " -> Package: $PackageName" -ForegroundColor Yellow
    Write-Host " -> Target:  $User@$Target" -ForegroundColor Yellow

    # 2. Preparation (Ensure dir exists)
    Write-Host "`n>>> [SSH] Preparing target..." -ForegroundColor Magenta
    $RemoteDir = "/data/incoming_updates"

    # Теперь мы ожидаем, что прав пользователя достаточно, либо ssh настроен
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$User@$Target" "mkdir -p $RemoteDir"
    if ($LASTEXITCODE -ne 0) { throw "SSH Connection Failed (mkdir)" }

    # 3. Transfer
    Write-Host "`n>>> [SCP] Uploading..." -ForegroundColor Magenta

    # Upload .tar.gz
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $PackagePath "$User@$Target`:$RemoteDir/"

    # Upload .sha256 (if exists)
    if (Test-Path $ShaFile) {
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $ShaFile "$User@$Target`:$RemoteDir/"
    }

    Write-Host " -> Upload Complete." -ForegroundColor Green

    # 4. Monitor / Log
    # Agent triggered by systemd-path (if installed)
    Write-Host "`n[INFO] Update file placed. System should detect it automatically." -ForegroundColor Gray

    if ($Log) {
        Write-Host ">>> [LOG] Tailing logs (Ctrl+C to stop)..." -ForegroundColor Cyan
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t "$User@$Target" "journalctl -u headunit-update-monitor -u headunit-update-agent -f"
    }

} catch {
    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
