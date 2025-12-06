<#
.SYNOPSIS
    Быстрая доставка кода приложения на работающее устройство (Hot Deploy).
    Не пересобирает образ системы, обновляет только контейнеры.

.EXAMPLE
    .\deploy.ps1 -Ip 192.168.50.10
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Ip,

    [string]$User = "cdreborn",
    [string]$KeyFile = "$HOME\.ssh\id_rsa" # Путь к вашему ключу, если есть
)

$ErrorActionPreference = "Stop"

# Пути на хосте (Windows)
$LocalSrc = "src"
$LocalDeploy = "deploy"
$LocalServices = "services"

# Пути на устройстве (Raspberry Pi)
# Мы договорились, что код живет в /data (rw раздел), а конфиги запуска в /opt
$RemoteAppDir = "/data/app"
$RemoteConfigDir = "/opt/headunit"

Write-Host ">>> HeadUnit Hot Deploy" -ForegroundColor Cyan
Write-Host "Target: $User@$Ip" -ForegroundColor Yellow

# 1. ПРОВЕРКА СВЯЗИ
Write-Host "`n[1/4] Checking connection..."
$Ping = Test-Connection -ComputerName $Ip -Count 1 -Quiet
if (-not $Ping) {
    Write-Error "Device $Ip is unreachable!"
    exit 1
}

# Функция для SSH команд
function Remote-Exec {
    param([string]$Cmd)
    # Используем ssh из Windows 10/11
    ssh -o StrictHostKeyChecking=no "$User@$Ip" "sudo bash -c '$Cmd'"
}

# 2. ПОДГОТОВКА ПАПОК
Write-Host "[2/4] Preparing remote directories..."
Remote-Exec "mkdir -p $RemoteAppDir $RemoteConfigDir"
# Даем права текущему пользователю, чтобы scp мог писать
Remote-Exec "chown -R $User:$User $RemoteAppDir $RemoteConfigDir"

# 3. СИНХРОНИЗАЦИЯ ФАЙЛОВ (SCP)
# Windows scp не умеет exclude, поэтому копируем папки целиком
Write-Host "[3/4] Syncing files..."

# Копируем исходный код
Write-Host "  -> Syncing src/..."
scp -r -o StrictHostKeyChecking=no $LocalSrc "$User@$Ip:$RemoteAppDir"

# Копируем сервисные конфиги
Write-Host "  -> Syncing services/..."
scp -r -o StrictHostKeyChecking=no $LocalServices "$User@$Ip:$RemoteAppDir"

# Копируем docker-compose
Write-Host "  -> Syncing docker-compose..."
scp -o StrictHostKeyChecking=no "$LocalDeploy/docker-compose.yml" "$User@$Ip:$RemoteConfigDir/"

# 4. ПЕРЕЗАПУСК ПРИЛОЖЕНИЯ
Write-Host "[4/4] Restarting Containers..."
# Мы используем --build, чтобы Docker на Pi пересобрал образ из новых файлов
Remote-Exec "cd $RemoteConfigDir && docker compose up -d --build --remove-orphans"

Write-Host "`n>>> Deploy Complete! 🚀" -ForegroundColor Green
