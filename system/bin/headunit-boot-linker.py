#!/usr/bin/env python3
import os
import json
import sys
import re

# --- КОНФИГУРАЦИЯ ---
RELEASE_FILE = "/etc/headunit-release"
FACTORY_DIR = "/opt/headunit/factory"
UPDATES_DIR = "/data/components"
RUNTIME_DIR = "/run/headunit"

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---


def parse_version(v_str):
    """Превращает '1.2.3' в кортеж (1, 2, 3) для сравнения."""
    # Убираем все кроме цифр и точек (на всякий случай)
    clean = re.sub(r"[^0-9\.]", "", v_str)
    try:
        return tuple(map(int, clean.split(".")))
    except ValueError:
        return (0, 0, 0)


def check_constraint(required_op, required_ver, actual_ver):
    """Проверяет условие: actual >= required"""
    # В рамках нашей упрощенной логики поддерживаем только '>='
    # required_op ожидается как '>='
    req_tuple = parse_version(required_ver)
    act_tuple = parse_version(actual_ver)
    return act_tuple >= req_tuple


def load_manifest(path):
    manifest_path = os.path.join(path, "manifest.json")
    if not os.path.exists(manifest_path):
        return None
    try:
        with open(manifest_path, "r") as f:
            return json.load(f)
    except Exception:
        return None


def get_os_version():
    """Читает версию OS из /etc/headunit-release"""
    ver = "0.0.0"
    if os.path.exists(RELEASE_FILE):
        with open(RELEASE_FILE, "r") as f:
            for line in f:
                if line.startswith("OS_VERSION="):
                    # Убираем кавычки
                    ver = line.strip().split("=", 1)[1].strip('"')
    return ver


def find_best_component(comp_name, dependency_key, dependency_version):
    """
    Ищет лучшую версию компонента (app или services).
    Сравнивает версии из Factory и Updates.
    Проверяет зависимость dependency_key >= dependency_version.
    """
    candidates = []

    # 1. Factory (Заводская версия)
    factory_path = os.path.join(FACTORY_DIR, comp_name)
    man = load_manifest(factory_path)
    if man:
        candidates.append(
            {
                "path": factory_path,
                "version": man.get("version", "0.0.0"),
                "deps": man.get("dependencies", {}),
            }
        )

    # 2. Updates (Обновления на data)
    update_base = os.path.join(UPDATES_DIR, comp_name)
    if os.path.exists(update_base):
        for item in os.listdir(update_base):
            path = os.path.join(update_base, item)
            if os.path.isdir(path):
                man = load_manifest(path)
                if man:
                    candidates.append(
                        {
                            "path": path,
                            "version": man.get("version", "0.0.0"),
                            "deps": man.get("dependencies", {}),
                        }
                    )

    # 3. Фильтрация и Сортировка
    valid_candidates = []
    print(
        f"[{comp_name}] Resolving dependency: {dependency_key} >= {dependency_version}"
    )

    for c in candidates:
        # Проверка зависимости
        req_str = c["deps"].get(dependency_key, ">=0.0.0")
        # Парсим строку вида ">=1.0.0"
        if ">=" in req_str:
            req_ver = req_str.replace(">=", "").strip()
            if check_constraint(">=", req_ver, dependency_version):
                # ВАЖНО: Мы проверяем, подходит ли НАЙДЕННЫЙ компонент под ТРЕБОВАНИЯ ТЕКУЩЕЙ СРЕДЫ?
                # Нет, наоборот.
                # Мы проверяем: Удовлетворяет ли СРЕДА (dependency_version) требования КОМПОНЕНТА (req_ver)?

                # Пример: App требует Services >= 1.0.
                # Текущие Services = 1.2.
                # App Manifest: "services": ">=1.0".
                # Проверка: 1.2 (Environment) >= 1.0 (Requirement). TRUE.

                if check_constraint(">=", req_ver, dependency_version):
                    valid_candidates.append(c)
                else:
                    print(
                        f"  - Skip {c['version']}: Requires {dependency_key} {req_str}, but available is {dependency_version}"
                    )
            else:
                # Если формат кривой, пропускаем
                print(f"  - Skip {c['version']}: Invalid dep format {req_str}")
        else:
            # Если требований нет или формат неизвестен - считаем совместимым (на страх и риск)
            valid_candidates.append(c)

    # Сортируем по версии убыванию (новейшая первая)
    valid_candidates.sort(key=lambda x: parse_version(x["version"]), reverse=True)

    if not valid_candidates:
        return None

    return valid_candidates[0]


def create_symlink(target, link_name):
    link_path = os.path.join(RUNTIME_DIR, link_name)
    if os.path.islink(link_path) or os.path.exists(link_path):
        os.remove(link_path)
    os.symlink(target, link_path)
    print(f"LINK: {link_name} -> {target}")


# --- MAIN ---


def main():
    if not os.path.exists(RUNTIME_DIR):
        os.makedirs(RUNTIME_DIR)

    # 1. Получаем версию ОС
    os_ver = get_os_version()
    print(f"BOOT-LINKER: OS Version detected: {os_ver}")

    # 2. Выбираем Services (зависят от OS)
    best_services = find_best_component("services", "os", os_ver)

    if not best_services:
        print("CRITICAL: No valid Services found compatible with this OS!")
        sys.exit(1)

    print(f"SELECTED: Services v{best_services['version']}")
    create_symlink(best_services["path"], "active_services")

    # 3. Выбираем App (зависит от Services)
    services_ver = best_services["version"]
    best_app = find_best_component("app", "services", services_ver)

    if not best_app:
        print("CRITICAL: No valid App found compatible with selected Services!")
        sys.exit(1)

    print(f"SELECTED: App v{best_app['version']}")
    create_symlink(best_app["path"], "active_app")


if __name__ == "__main__":
    main()
