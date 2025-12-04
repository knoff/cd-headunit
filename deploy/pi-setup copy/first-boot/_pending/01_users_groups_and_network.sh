#!/usr/bin/env bash
set -euo pipefail
BOOT="/boot"; [ -d /boot/firmware ] && BOOT="/boot/firmware"
echo "start: users/network/base"

mkdir -p /data /factory
mount -a || true
mkdir -p /data/{var_lib_docker,var_log,srv}

CONF="$BOOT/device.conf"
[ -s "$CONF" ] || { echo "[01][FATAL] no device.conf"; exit 1; }
. "$CONF"

# утилиты imager_custom / userconf (с фолбэком)
IMAGER="${IMAGER:-}"; USERCONF="${USERCONF:-}"
[ -z "$IMAGER" ]   && { [ -x "$BOOT/first-boot/lib/imager_custom" ] && IMAGER="$BOOT/first-boot/lib/imager_custom"; }
[ -z "$IMAGER" ]   && { [ -x /usr/lib/raspberrypi-sys-mods/imager_custom ] && IMAGER=/usr/lib/raspberrypi-sys-mods/imager_custom; }
[ -z "$USERCONF" ] && { [ -x "$BOOT/first-boot/lib/userconf" ] && USERCONF="$BOOT/first-boot/lib/userconf"; }
[ -z "$USERCONF" ] && { [ -x /usr/lib/userconf-pi/userconf ] && USERCONF=/usr/lib/userconf-pi/userconf; }
[ -x "$IMAGER" ] && [ -x "$USERCONF" ] || { echo "[01][FATAL] no imager_custom/userconf"; exit 1; }

# hostname
[ -n "${DEVICE_HOSTNAME:-}" ] && "$IMAGER" set_hostname "$DEVICE_HOSTNAME" || true

# SSH
"$IMAGER" enable_ssh || true

# user+password (с дефолтами)
USER_NAME="${USER_NAME:-cdreborn}"
USER_PASSWORD="${USER_PASSWORD:-brewme}"
if command -v openssl >/dev/null 2>&1; then
  HASH="$(openssl passwd -6 "$USER_PASSWORD" 2>/dev/null || true)"
  [ -n "$HASH" ] && "$USERCONF" "$USER_NAME" "$HASH"
fi
getent group docker >/dev/null 2>&1 || groupadd -r docker 2>/dev/null || true
usermod -aG sudo "$USER_NAME" 2>/dev/null || true
usermod -aG docker "$USER_NAME" 2>/dev/null || true

# Wi-Fi (HEX если можем, иначе plaintext)
SSID="${WIFI_SSID:-}"; PASS="${WIFI_PASS:-}"; COUNTRY="${WIFI_COUNTRY:-RU}"
if [ -n "$SSID" ]; then
  if [ -n "$PASS" ] && command -v wpa_passphrase >/dev/null 2>&1; then
    PSK_HEX="$(wpa_passphrase "$SSID" "$PASS" | awk '/^\s*psk=/{if ($0 !~ /^#/) print $0}' | tail -n1 | cut -d= -f2)"
    if [ -n "$PSK_HEX" ]; then "$IMAGER" set_wlan "$SSID" "$PSK_HEX" "$COUNTRY"; else "$IMAGER" set_wlan -p "$SSID" "$PASS" "$COUNTRY"; fi
  else
    "$IMAGER" set_wlan -p "$SSID" "$PASS" "$COUNTRY"
  fi
fi

# TZ/Keymap
"$IMAGER" set_timezone "${TIMEZONE:-Europe/Moscow}" || true
"$IMAGER" set_keymap   "${KEYMAP:-us}" || true

echo "done"
exit 0
