#!/usr/bin/env python3
"""
HeadUnit Configuration Library
Central logic for managing device configuration (Factory Defaults + User Overrides).
"""

import os
import json

# Пути к файлам
USER_CONFIG_FILE = "/data/configs/user_settings.json"
FACTORY_CONFIG_FILE = "/etc/headunit/factory_defaults.json"

# Хардкод на случай тотального сбоя fs
DEFAULT_CONFIG = {
    "serial": "CDR-GENERIC",
    "wifi_app_pass": "password123",
    "wifi_client_ssid": "",
    "wifi_client_pass": "",
    "wifi_country": "RU",
}


def get_defaults():
    """Читает заводские настройки (генерируются сборщиком)"""
    defaults = DEFAULT_CONFIG.copy()
    if os.path.exists(FACTORY_CONFIG_FILE):
        try:
            with open(FACTORY_CONFIG_FILE, "r") as f:
                defaults.update(json.load(f))
        except (json.JSONDecodeError, OSError):
            pass  # Игнорируем битый файл, используем хардкод
    return defaults


def load_config():
    """
    Загружает итоговую конфигурацию.
    Приоритет: User Config > Factory Defaults > Hardcoded
    """
    config = get_defaults()

    if os.path.exists(USER_CONFIG_FILE):
        try:
            with open(USER_CONFIG_FILE, "r") as f:
                user_data = json.load(f)
                config.update(user_data)
        except (json.JSONDecodeError, OSError):
            pass  # Игнорируем ошибки чтения пользовательского конфига

    return config


def save_config(config):
    """Сохраняет настройки пользователя"""
    try:
        os.makedirs(os.path.dirname(USER_CONFIG_FILE), exist_ok=True)
        with open(USER_CONFIG_FILE, "w") as f:
            json.dump(config, f, indent=2)
        return True
    except Exception as e:
        print(f"Error saving config: {e}")
        return False
