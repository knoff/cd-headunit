import os
import sys
import json
import logging

# Добавляем путь к системным библиотекам для импорта hu_config
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SYSTEM_LIB_PATH = os.path.join(os.path.dirname(BASE_DIR), "system", "lib")
if SYSTEM_LIB_PATH not in sys.path:
    sys.path.append(SYSTEM_LIB_PATH)

try:
    import hu_config
except ImportError:
    logging.error(f"Could not import hu_config from {SYSTEM_LIB_PATH}")
    # Фоллбек для разработки, если hu_config не найден
    class MockHuConfig:
        USER_CONFIG_FILE = os.path.join(BASE_DIR, "user_settings_dev.json")
        def load_config(self):
            if os.path.exists(self.USER_CONFIG_FILE):
                with open(self.USER_CONFIG_FILE, 'r') as f: return json.load(f)
            return {"serial": "CDR-DEV", "wifi_country": "RU"}
        def save_config(self, cfg):
            with open(self.USER_CONFIG_FILE, 'w') as f: json.dump(cfg, f, indent=2)
            return True
    hu_config = MockHuConfig()

# Настраиваем пути для разработки на Windows
if os.name == 'nt':
    hu_config.USER_CONFIG_FILE = os.path.join(BASE_DIR, "user_settings_dev.json")
    # Создаем директорию если ее нет
    os.makedirs(os.path.dirname(hu_config.USER_CONFIG_FILE), exist_ok=True)

def get_settings():
    return hu_config.load_config()



def _check_ntp_availability():
    """Проверяем доступность NTP (эмуляция или реальный тест)"""
    if os.name == 'nt':
        return True # На винде считаем что доступен

    try:
        # Пингуем пул ntp.org или проверяем статус timedatectl
        # Для простоты и скорости - проверяем статус
        res = subprocess.run(["timedatectl", "show-timesync", "--property=SystemNTPServers"], capture_output=True, text=True)
        return res.returncode == 0
    except Exception:
        return False

def update_settings(new_settings):
    cfg = hu_config.load_config()

    # 1. Логика NTP и Timezone (дефолты если нет)
    # Если в конфиге нет timezone, ставим дефолт
    if "timezone" not in cfg:
        cfg["timezone"] = "Europe/Moscow"

    # Обработка system_time (Ручная установка)
    if "system_time" in new_settings:
        manual_time = new_settings.pop("system_time") # Удаляем, чтобы не сохранять в конфиг
        logging.info(f"Setting manual time: {manual_time}")

        if os.name == 'nt':
            logging.info(f"[MOCK] timedatectl set-time '{manual_time}'")
        else:
            try:
                subprocess.run(["timedatectl", "set-ntp", "false"], check=True) # Сначала гасим NTP
                subprocess.run(["timedatectl", "set-time", manual_time], check=True)
                # При ручной установке NTP должен стать false в конфиге
                cfg["ntp_enabled"] = False
                new_settings["ntp_enabled"] = False
            except Exception as e:
                logging.error(f"Failed to set system time: {e}")
                return False

    # Обработка NTP
    if "ntp_enabled" in new_settings:
        ntp_state = new_settings["ntp_enabled"]
        if ntp_state:
            # Если включаем NTP - проверяем доступность
            if not _check_ntp_availability():
                logging.warning("NTP requested but not available. Reverting to manual.")
                new_settings["ntp_enabled"] = False
                # TODO: Можно как-то сообщить фронту об ошибке, но пока просто сбрасываем

            if os.name == 'nt':
                logging.info(f"[MOCK] timedatectl set-ntp {new_settings['ntp_enabled']}")
            else:
                try:
                    subprocess.run(["timedatectl", "set-ntp", str(new_settings['ntp_enabled']).lower()], check=True)
                except Exception as e:
                    logging.error(f"Failed to set NTP: {e}")

    # Обработка Timezone
    if "timezone" in new_settings and new_settings["timezone"] != cfg.get("timezone"):
        tz = new_settings["timezone"]
        if os.name == 'nt':
            logging.info(f"[MOCK] timedatectl set-timezone {tz}")
        else:
            try:
                subprocess.run(["timedatectl", "set-timezone", tz], check=True)
            except Exception as e:
                logging.error(f"Failed to set timezone: {e}")

    cfg.update(new_settings)

    if hu_config.save_config(cfg):
        # На реальном устройстве вызываем применение остальных настроек (сеть и т.д.)
        if os.name != 'nt':
            try:
                import subprocess
                subprocess.run(["sudo", "/usr/local/bin/headunit-apply-config"], check=True)
            except Exception as e:
                logging.error(f"Failed to apply settings: {e}")
        return True
    return False
