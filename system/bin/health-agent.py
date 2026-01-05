#!/usr/bin/env python3
"""
HeadUnit Health Agent v3 (Multi-Layer)
Запускает диагностику по уровням: System -> Services -> App.
Использует BATS тесты из активных компонентов.
"""

import sys
import subprocess
import shutil
import os

# Определение слоев тестирования
# (Название, Путь, Обязательность)
TEST_LAYERS = [
    {
        "name": "SYSTEM KERNEL & DRIVERS",
        "path": "/opt/headunit/tests/runtime",
        "required": True,
    },
    {
        "name": "SERVICES & INFRASTRUCTURE",
        # Ссылка, созданная boot-linker'ом на активную версию
        "path": "/run/headunit/active_services/tests",
        "required": False,
    },
    {
        "name": "APPLICATION LOGIC",
        # Ссылка на активную версию приложения
        "path": "/run/headunit/active_app/tests",
        "required": False,
    },
]


class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    GREY = "\033[90m"
    BOLD = "\033[1m"
    RESET = "\033[0m"


def run_test_file(bats_path, filepath):
    """
    Запускает один BATS файл и парсит его вывод.
    Возвращает кортеж (passed, warnings, failed)
    """
    filename = os.path.basename(filepath)
    print(f"  {Colors.CYAN}📦 [{filename}]{Colors.RESET}")

    cmd = [bats_path, "--tap", filepath]

    passed = 0
    warnings = 0
    failed = 0

    try:
        process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )

        for line in process.stdout:
            line = line.strip()

            if line.startswith("1..") or not line:
                continue

            if line.startswith("ok"):
                description = line.split(" ", 2)[-1]
                if "# skip" in line:
                    if "WARN:" in line:
                        parts = line.split("# skip WARN:", 1)
                        test_name = parts[0].replace("-", "").strip()
                        reason = parts[1].strip()
                        print(f"    {Colors.YELLOW}⚠ WARN{Colors.RESET} {test_name}")
                        print(f"         └─ {reason}")
                        warnings += 1
                    else:
                        print(f"    {Colors.BLUE}SKIP{Colors.RESET} {description}")
                else:
                    clean_desc = (
                        description.split("-", 1)[-1].strip()
                        if "-" in description
                        else description
                    )
                    print(f"    {Colors.GREEN}✔ PASS{Colors.RESET} {clean_desc}")
                    passed += 1

            elif line.startswith("not ok"):
                failed += 1
                description = line.split(" ", 2)[-1]
                print(f"    {Colors.RED}✖ FAIL{Colors.RESET} {description}")

        process.wait()
        return passed, warnings, failed

    except Exception as e:
        print(f"    {Colors.RED}Execution Error: {e}{Colors.RESET}")
        return 0, 0, 1


def process_layer(layer, bats_path):
    """Обрабатывает один слой тестов"""
    name = layer["name"]
    path = layer["path"]
    required = layer["required"]

    print(f"\n{Colors.BOLD}=== LAYER: {name} ==={Colors.RESET}")

    if not os.path.exists(path):
        if required:
            print(
                f"{Colors.RED}[CRITICAL] Test directory missing: {path}{Colors.RESET}"
            )
            return 0, 0, 1  # Critical failure
        else:
            print(
                f"{Colors.GREY}[INFO] No tests found (path does not exist).{Colors.RESET}"
            )
            return 0, 0, 0

    files = sorted(
        [os.path.join(path, f) for f in os.listdir(path) if f.endswith(".bats")]
    )

    if not files:
        print(f"{Colors.GREY}[INFO] Directory empty.{Colors.RESET}")
        return 0, 0, 0

    l_pass = 0
    l_warn = 0
    l_fail = 0

    for f in files:
        p, w, f_cnt = run_test_file(bats_path, f)
        l_pass += p
        l_warn += w
        l_fail += f_cnt

    return l_pass, l_warn, l_fail


def main():
    print(f"{Colors.HEADER}>>> HeadUnit Health Check System v3{Colors.RESET}")

    bats_path = shutil.which("bats")
    if not bats_path:
        print(f"{Colors.RED}[CRITICAL] 'bats' utility not found!{Colors.RESET}")
        sys.exit(1)

    total_pass = 0
    total_warn = 0
    total_fail = 0

    for layer in TEST_LAYERS:
        p, w, f = process_layer(layer, bats_path)
        total_pass += p
        total_warn += w
        total_fail += f

    print("\n" + "═" * 50)
    summary_line = (
        f"Total: {total_pass} Passed, {total_warn} Warnings, {total_fail} Failed"
    )
    print(summary_line)

    if total_fail > 0:
        print(f"{Colors.RED}✘ SYSTEM ISSUES DETECTED{Colors.RESET}")
        sys.exit(1)
    elif total_warn > 0:
        print(f"{Colors.YELLOW}⚠ Operational with Warnings{Colors.RESET}")
        sys.exit(0)
    else:
        print(f"{Colors.GREEN}✔ All Systems Operational{Colors.RESET}")
        sys.exit(0)


if __name__ == "__main__":
    main()
