#!/usr/bin/env python3
"""
HeadUnit Health Agent v2
Группирует тесты по файлам и фильтрует технический шум BATS.
"""

import sys
import subprocess
import shutil
import os

TESTS_DIR = "/opt/headunit/tests/runtime"


class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    GREY = "\033[90m"
    RESET = "\033[0m"


def run_test_file(bats_path, filepath):
    """
    Запускает один BATS файл и парсит его вывод.
    Возвращает кортеж (passed, warnings, failed)
    """
    filename = os.path.basename(filepath)
    # Печатаем заголовок модуля
    print(f"\n{Colors.CYAN}📦 [{filename}]{Colors.RESET}")

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

            # Игнорируем технические заголовки TAP
            if line.startswith("1..") or not line:
                continue

            if line.startswith("ok"):
                # Обработка PASS и WARN (через skip)
                description = line.split(" ", 2)[-1]  # Убираем 'ok <num>'

                if "# skip" in line:
                    if "WARN:" in line:
                        # Формат: ... # skip WARN: Reason
                        parts = line.split("# skip WARN:", 1)
                        # Чистим имя теста от мусора
                        test_name = parts[0].replace("-", "").strip()
                        reason = parts[1].strip()

                        print(f"  {Colors.YELLOW}⚠ WARN{Colors.RESET} {test_name}")
                        print(f"       └─ {reason}")
                        warnings += 1
                    else:
                        # Обычный skip
                        print(f"  {Colors.BLUE}SKIP{Colors.RESET} {description}")
                else:
                    # Чистый PASS
                    clean_desc = (
                        description.split("-", 1)[-1].strip()
                        if "-" in description
                        else description
                    )
                    print(f"  {Colors.GREEN}✔ PASS{Colors.RESET} {clean_desc}")
                    passed += 1

            elif line.startswith("not ok"):
                failed += 1
                # Убираем 'not ok <num>'
                description = line.split(" ", 2)[-1]
                print(f"  {Colors.RED}✖ FAIL{Colors.RESET} {description}")

            elif line.startswith("#"):
                # ФИЛЬТРАЦИЯ ШУМА
                # BATS пишет отладочную инфу через #.
                # Мы игнорируем всё, кроме явных сообщений, которые мы можем захотеть (опционально)
                # Если вы хотите видеть вывод echo внутри тестов, можно добавить логику.
                # Сейчас мы просто скрываем весь шум:
                continue

        process.wait()
        return passed, warnings, failed

    except Exception as e:
        print(f"{Colors.RED}  Execution Error: {e}{Colors.RESET}")
        return 0, 0, 1


def main():
    print(f"{Colors.HEADER}>>> HeadUnit Health Check System{Colors.RESET}")
    print(f"Target: {TESTS_DIR}")

    bats_path = shutil.which("bats")
    if not bats_path:
        print(f"{Colors.RED}[CRITICAL] 'bats' not found!{Colors.RESET}")
        sys.exit(1)

    if not os.path.isdir(TESTS_DIR):
        print(f"{Colors.RED}[ERROR] Directory not found.{Colors.RESET}")
        sys.exit(1)

    # Ищем все .bats файлы
    files = sorted(
        [
            os.path.join(TESTS_DIR, f)
            for f in os.listdir(TESTS_DIR)
            if f.endswith(".bats")
        ]
    )

    if not files:
        print(f"{Colors.YELLOW}No tests found.{Colors.RESET}")
        sys.exit(0)

    total_pass = 0
    total_warn = 0
    total_fail = 0

    # Запускаем пофайлово
    for f in files:
        p, w, f_count = run_test_file(bats_path, f)
        total_pass += p
        total_warn += w
        total_fail += f_count

    print("\n" + "═" * 40)
    print(f"Summary: {total_pass} Passed, {total_warn} Warnings, {total_fail} Failed")

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
