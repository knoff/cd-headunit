param(
  [string]$SourceDir = ".\pi-setup"   # папка с firstrun.sh и first-boot\pending\
)

function Step($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }

if (!(Test-Path $SourceDir)) { Warn "Нет папки $SourceDir. Выходим."; return }

function Pick-BootDrive {
  $v = Get-Volume | ? { $_.FileSystem -match 'FAT' -and $_.DriveLetter -and ($_.FileSystemLabel -match '^(boot|bootfs)$') }
  if ($v.Count -eq 1) { return ("{0}:" -f $v.DriveLetter) }
  if ($v.Count -gt 1) {
    Warn "Найдено несколько boot-томов:"; $v | % { "{0}: {1}" -f $_.DriveLetter, $_.FileSystemLabel | Write-Host }
  }
  $dl = Read-Host "Буква диска (напр. E)"; return ($dl.TrimEnd(':') + ":")
}

$boot = Pick-BootDrive
if (!(Test-Path "$boot\")) { Warn "Том $boot\ недоступен"; return }
Ok "Boot том: $boot\"

# 1) Копируем firstrun.sh
$frSrc = Join-Path $SourceDir "firstrun.sh"
if (!(Test-Path $frSrc)) { Warn "Нет $frSrc"; return }
Step "Копирую firstrun.sh"
$t = (Get-Content $frSrc -Raw) -replace "`r`n","`n"
if (-not $t.StartsWith("#!")) { $t = "#!/bin/sh`n" + $t }
Set-Content -Path (Join-Path $boot "firstrun.sh") -Value $t -Encoding Ascii

# 2) Копируем first-boot/pending
$pendingSrc = Join-Path $SourceDir "first-boot\pending"
if (!(Test-Path $pendingSrc)) { Warn "Нет $pendingSrc"; return }
Step "Копирую first-boot\pending"
New-Item -ItemType Directory -Force -Path (Join-Path $boot "first-boot\pending") | Out-Null
Copy-Item (Join-Path $pendingSrc "*") -Destination (Join-Path $boot "first-boot\pending") -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $boot "first-boot\completed") | Out-Null

# 3) Нормализуем все *.sh
Step "Нормализую *.sh"
Get-ChildItem -Path (Join-Path $boot "first-boot") -Filter *.sh -Recurse |
  % { $c = (Get-Content $_.FullName -Raw) -replace "`r`n","`n"; if (-not $c.StartsWith("#!")) { $c = "#!/usr/bin/env bash`n" + $c }; Set-Content $_.FullName -Value $c -Encoding Ascii }

# 4) /boot/logs
Step "Создаю /boot/logs"
$logs = Join-Path $boot "logs"; if (!(Test-Path $logs)) { New-Item $logs -ItemType Directory | Out-Null }

# 5) Чистим только 'resize' в cmdline.txt
$cmd = Join-Path $boot "cmdline.txt"
if (Test-Path $cmd) {
  Step "Чищу resize в cmdline.txt"
  $line = Get-Content $cmd -Raw
  $line = ($line -replace "\s+resize(\s+|$)", " ") -replace "\s{2,}"," "
  Set-Content -Path $cmd -Value $line -Encoding Ascii
} else { Warn "cmdline.txt не найден" }

Ok "Готово. Можно извлекать карту."
