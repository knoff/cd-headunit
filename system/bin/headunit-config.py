#!/usr/bin/env python3
"""
HeadUnit Configuration Wizard
TUI утилита для настройки параметров устройства.
"""

import sys
import os
import subprocess
import re

import hu_config  # type: ignore

# В образе скрипт лежит без расширения .py (по вашему решению)
APPLY_SCRIPT = "/usr/local/bin/headunit-apply-config"


# --- WHIPTAIL WRAPPERS ---
def wt_msgbox(title, text):
    subprocess.run(["whiptail", "--title", title, "--msgbox", text, "10", "60"])


def wt_input(title, text, default=""):
    res = subprocess.run(
        ["whiptail", "--title", title, "--inputbox", text, "10", "60", default],
        stderr=subprocess.PIPE,
    )
    return res.stderr.decode("utf-8") if res.returncode == 0 else None


def wt_password(title, text):
    res = subprocess.run(
        ["whiptail", "--title", title, "--passwordbox", text, "10", "60"],
        stderr=subprocess.PIPE,
    )
    return res.stderr.decode("utf-8") if res.returncode == 0 else None


def wt_menu(title, text, items):
    cmd = ["whiptail", "--title", title, "--menu", text, "15", "60", "5"]
    for tag, desc in items:
        cmd.extend([tag, desc])
    res = subprocess.run(cmd, stderr=subprocess.PIPE)
    return res.stderr.decode("utf-8") if res.returncode == 0 else None


def wt_yesno(title, text):
    res = subprocess.run(["whiptail", "--title", title, "--yesno", text, "10", "60"])
    return res.returncode == 0


def enable_persistence():
    """Включает сервис identity, чтобы настройки применялись при загрузке"""
    try:
        # enable --now сразу и включает автозагрузку, и запускает сервис (или перечитывает его)
        subprocess.run(
            ["systemctl", "enable", "headunit-identity.service"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def apply_settings():
    """Запускает применение настроек здесь и сейчас"""
    try:
        # Сначала включаем персистентность
        enable_persistence()
        # Потом применяем настройки
        subprocess.run([APPLY_SCRIPT], check=True)
        return True
    except subprocess.CalledProcessError:
        wt_msgbox("Error", "Failed to apply settings.")
        return False
    except Exception as e:
        wt_msgbox("Error", f"System Error:\n{e}")
        return False


# --- LOGIC ---
def validate_serial(sn):
    return re.match(r"^[A-Z]{3}-\d{8}$", sn) is not None


def derive_params(sn):
    parts = sn.split("-")
    if len(parts) != 2:
        return None, None
    return f"cdreborn-{parts[1]}", sn


def menu_serial(config):
    while True:
        current = config.get("serial", "")
        new_sn = wt_input("Serial Setup", "Enter Serial (CDR-00010002):", current)
        if new_sn is None:
            return

        new_sn = new_sn.upper().strip()
        if not validate_serial(new_sn):
            wt_msgbox("Error", "Invalid format!")
            continue

        host, ssid = derive_params(new_sn)
        if wt_yesno(
            "Confirm", f"Serial: {new_sn}\nHost: {host}\nSSID: {ssid}\n\nSave?"
        ):
            config["serial"] = new_sn
            if hu_config.save_config(config):
                if apply_settings():
                    wt_msgbox("Success", "Identity updated.")
                    break
            else:
                wt_msgbox("Error", "Failed to save config file.")


def menu_wifi(config):
    ssid = wt_input("Wi-Fi", "SSID:", config.get("wifi_client_ssid", ""))
    if ssid is None:
        return
    password = wt_password(
        "Wi-Fi",
        "Password:",
    )
    if password is None:
        return
    country = wt_input("Wi-Fi", "Country (RU):", config.get("wifi_country", "RU"))
    if country is None:
        return

    config["wifi_client_ssid"] = ssid
    config["wifi_client_pass"] = password
    config["wifi_country"] = country.upper()

    if hu_config.save_config(config):
        if apply_settings():
            wt_msgbox("Success", "Wi-Fi settings saved.")
    else:
        wt_msgbox("Error", "Failed to save config file.")


def main_menu():
    while True:
        cfg = hu_config.load_config()
        sn = cfg.get("serial", "N/A")
        # Убрали пункт 3 (Info)
        choice = wt_menu(
            "Config Tool",
            f"SN: {sn}",
            [("1", "Set Serial"), ("2", "Setup Wi-Fi"), ("3", "Reboot"), ("0", "Exit")],
        )

        if choice == "1":
            menu_serial(cfg)
        elif choice == "2":
            menu_wifi(cfg)
        elif choice == "3":
            if wt_yesno("Reboot", "Reboot?"):
                subprocess.run(["reboot"])
        else:
            break


if __name__ == "__main__":
    if os.geteuid() != 0:
        print("Root required")
        sys.exit(1)
    try:
        main_menu()
    except KeyboardInterrupt:
        sys.exit(0)
