#!/usr/bin/env bash
# v1 — initialize hostname, user, and networking from /boot/firmware/device.conf
set -euo pipefail

# --- BOOT path autodetect ---
BOOT="/boot"
if [[ -d /boot/firmware ]]; then
  BOOT="/boot/firmware"
fi

CMDLINE="${BOOT}/cmdline.txt"
FIRSTBOOT_DIR="${BOOT}/first-boot"

CONF="${BOOT}/device.conf"
[[ -f "$CONF" ]] || exit 0
log(){ echo "[device-init] $*"; }
set -a; source "$CONF"; set +a

# Hostname
if [[ -n "${DEVICE_HOSTNAME:-}" ]]; then
  log "Setting hostname to ${DEVICE_HOSTNAME}"
  hostnamectl set-hostname "${DEVICE_HOSTNAME}"
  echo "${DEVICE_HOSTNAME}" > /etc/hostname
fi

# User
if [[ -n "${USER_NAME:-}" ]]; then
  if id "${USER_NAME}" &>/dev/null; then
    log "User ${USER_NAME} exists"
  else
    log "Creating user ${USER_NAME}"
    useradd -m -s /bin/bash "${USER_NAME}"
    [[ -n "${USER_PASSWORD:-}" ]] && echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd
    usermod -aG sudo,docker "${USER_NAME}" || true
  fi
fi

# Detect adapters (wlan0 builtin, wlan1 USB)
BUILTIN_IF=$(iw dev | awk '/Interface/ {print $2}' | grep -m1 wlan0 || true)
USB_IF=$(iw dev | awk '/Interface/ {print $2}' | grep -m1 wlan1 || true)
AP_IF="${USB_IF:-${BUILTIN_IF:-wlan0}}"
CLIENT_IF="${BUILTIN_IF:-wlan0}"

# External Wi-Fi (client)
if [[ -n "${WIFI_SSID:-}" && -n "${WIFI_PASS:-}" ]]; then
  log "Configuring external Wi-Fi SSID=${WIFI_SSID} on ${CLIENT_IF}"
  install -D -m 0644 /dev/null /etc/wpa_supplicant/wpa_supplicant.conf
  cat >/etc/wpa_supplicant/wpa_supplicant.conf <<EOF
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
network={
  ssid="${WIFI_SSID}"
  psk="${WIFI_PASS}"
  key_mgmt=WPA-PSK
  priority=10
}
EOF
fi

# AP (hostapd + dnsmasq) on wlan1 (USB) if present, otherwise builtin
if [[ -n "${AP_SSID:-}" && -n "${AP_PASS:-}" ]]; then
  log "Installing AP packages (hostapd, dnsmasq)"
  apt-get update -y && apt-get install -y hostapd dnsmasq
  log "Configuring AP on ${AP_IF} SSID=${AP_SSID}"
  cat >/etc/hostapd/hostapd.conf <<EOF
interface=${AP_IF}
ssid=${AP_SSID}
hw_mode=g
channel=${AP_CHANNEL:-6}
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${AP_PASS}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

  cat >/etc/dnsmasq.d/ap.conf <<EOF
interface=${AP_IF}
dhcp-range=192.168.50.10,192.168.50.100,255.255.255.0,24h
EOF

  cat >>/etc/dhcpcd.conf <<EOF

interface ${AP_IF}
static ip_address=${AP_ADDRESS:-192.168.50.1}/24
nohook wpa_supplicant
EOF

  systemctl enable hostapd dnsmasq
fi

# Route metrics: prefer eth0 > wlan0
install -D -m 0755 /dev/null /etc/dhcpcd.exit-hook
cat >/etc/dhcpcd.exit-hook <<'EOF'
#!/bin/bash
if [[ "$interface" == "eth0" ]]; then
  ip route replace default dev eth0 metric 100 || true
elif [[ "$interface" == "wlan0" ]]; then
  ip route replace default dev wlan0 metric 200 || true
fi
EOF
chmod +x /etc/dhcpcd.exit-hook

log "Device network initialization complete."
