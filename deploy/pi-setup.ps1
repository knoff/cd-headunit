# pi-setup.ps1
$ErrorActionPreference = 'Stop'
$setupDir = Join-Path $PSScriptRoot 'pi-setup'
if (!(Test-Path $setupDir)) {
    Write-Error "Папка 'pi-setup' не найдена рядом со скриптом."
    exit 1
}

$bootVolumes = Get-Volume | Where-Object {
    ($_.FileSystemLabel -match 'boot') -or (Test-Path "$($_.DriveLetter):\cmdline.txt")
}

if ($bootVolumes.Count -eq 0) {
    Write-Error "Не найден раздел boot с файлом cmdline.txt."
    exit 1
}
elseif ($bootVolumes.Count -gt 1) {
    Write-Host "Найдено несколько разделов boot:"
    $bootVolumes | ForEach-Object { Write-Host "$($_.DriveLetter): Label=$($_.FileSystemLabel)" }
    $driveLetter = Read-Host "Введите букву тома для раздела boot (без двоеточия)"
} else {
    $driveLetter = $bootVolumes[0].DriveLetter
}
$boot = "$driveLetter`:\"  # например "E:\"

Write-Host "Используется раздел boot: $boot"

# Копируем папку pi-setup на корень раздела boot
Copy-Item -Path (Join-Path $setupDir '*') -Destination $boot -Recurse -Force

Write-Host "Файлы скопированы."

# Правим cmdline.txt
$cmdlinePath = Join-Path $boot 'cmdline.txt'
if (Test-Path $cmdlinePath) {
  $cmdline = Get-Content $cmdlinePath -Raw
  $cmdline = $cmdline -replace ' init_resize=[^\s]+' , ''
  $cmdline = ($cmdline -replace "\s+resize(\s+|$)", " ") -replace "\s{2,}"," "
  $cmdline = $cmdline -replace 'systemd\.run=[^\s]+' , ''
  $cmdline = $cmdline.Trim() + ' systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target'
  Set-Content  -Path $cmdlinePath -Value $cmdline -NoNewline -Encoding Ascii
} else { Warn "cmdline.txt не найден" }

Write-Host "cmdline.txt обновлён."

Write-Host "Готово. Извлеките карту и вставьте в Raspberry Pi."
