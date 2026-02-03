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

def update_settings(new_settings):
    cfg = hu_config.load_config()
    cfg.update(new_settings)
    if hu_config.save_config(cfg):
        # На реальном устройстве вызываем применение настроек
        if os.name != 'nt':
            try:
                import subprocess
                subprocess.run(["sudo", "/usr/local/bin/headunit-apply-config"], check=True)
            except Exception as e:
                logging.error(f"Failed to apply settings: {e}")
        return True
    return False
