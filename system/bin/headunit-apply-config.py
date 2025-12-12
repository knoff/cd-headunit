#!/usr/bin/env python3
import os
import subprocess
import uuid

import hu_config  # type: ignore

NM_CONN_DIR = "/etc/NetworkManager/system-connections"


def set_hostname(hostname):
    current = subprocess.getoutput("hostname").strip()
    if current != hostname:
        print(f"Applying hostname: {hostname}")
        with open("/etc/hostname", "w") as f:
            f.write(hostname)
        subprocess.run(["hostnamectl", "set-hostname", hostname])
        with open("/etc/hosts", "w") as f:
            f.write(f"127.0.0.1\tlocalhost\n127.0.1.1\t{hostname}\n")


def configure_ap(serial, password):
    parts = serial.split("-")
    if len(parts) != 2:
        return

    ssid = serial

    psk = password if password else "headunit123"

    print(f"Applying AP: {ssid}")

    config = f"""[connection]
id=internal-ap
uuid={uuid.uuid4()}
type=wifi
interface-name=wlan0
autoconnect=true
autoconnect-priority=110

[wifi]
mode=ap
ssid={ssid}

[wifi-security]
key-mgmt=wpa-psk
psk={psk}

[ipv4]
method=shared
address1=192.168.50.1/24

[ipv6]
addr-gen-mode=default
method=ignore
"""
    path = os.path.join(NM_CONN_DIR, "internal-ap.nmconnection")
    with open(path, "w") as f:
        f.write(config)
    os.chmod(path, 0o600)


def configure_client(ssid, password, country):
    path = os.path.join(NM_CONN_DIR, "preconfigured-wifi.nmconnection")
    if not ssid:
        if os.path.exists(path):
            os.remove(path)
        return

    print(f"Applying Client: {ssid}")
    sec = f"\n[wifi-security]\nkey-mgmt=wpa-psk\npsk={password}\n" if password else ""

    config = f"""[connection]
id=preconfigured-wifi
uuid={uuid.uuid4()}
type=wifi
interface-name=wlan1
autoconnect=true
autoconnect-priority=100

[wifi]
mode=infrastructure
ssid={ssid}
{sec}
[ipv4]
method=auto
[ipv6]
addr-gen-mode=default
method=auto
"""
    with open(path, "w") as f:
        f.write(config)
    os.chmod(path, 0o600)


def main():
    # 1. Защита: Если пользовательского конфига нет — ничего не делаем.
    # Работают статические файлы, созданные при сборке.
    if not os.path.exists(hu_config.USER_CONFIG_FILE):
        print("No user config found. Keeping factory defaults.")
        return

    # 2. Если конфиг есть — применяем его
    cfg = hu_config.load_config()
    sn = cfg.get("serial")

    if sn and sn != "CDR-00000000":
        parts = sn.split("-")
        if len(parts) == 2:
            set_hostname(f"cdreborn-{parts[1]}")
            configure_ap(sn, cfg.get("wifi_app_pass"))

    configure_client(
        cfg.get("wifi_client_ssid"),
        cfg.get("wifi_client_pass"),
        cfg.get("wifi_country"),
    )

    subprocess.run(["nmcli", "connection", "reload"])
    subprocess.run(
        ["nmcli", "connection", "up", "internal-ap"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if cfg.get("wifi_client_ssid"):
        subprocess.run(
            ["nmcli", "connection", "up", "preconfigured-wifi"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


if __name__ == "__main__":
    main()
