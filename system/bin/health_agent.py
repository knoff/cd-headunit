#!/usr/bin/env python3
"""
HeadUnit Health Agent (BATS Wrapper)
"""

import sys
import subprocess
import shutil

# Путь к тестам
TESTS_DIR = "/opt/headunit/tests/runtime"


class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    GREEN = "\033[92m"
    RED = "\033[91m"
    RESET = "\033[0m"


def main():
    print(f"{Colors.HEADER}>>> HeadUnit Health Check System{Colors.RESET}")

    # 1. Проверяем наличие BATS
    bats_path = shutil.which("bats")
    if not bats_path:
        print(f"{Colors.RED}[CRITICAL] 'bats' framework not found!{Colors.RESET}")
        print("Please install bats-core.")
        sys.exit(1)

    # 2. Запускаем тесты
    # --pretty : красивый вывод галочками
    # --recursive : искать во всех подпапках
    cmd = [bats_path, "--pretty", "--recursive", TESTS_DIR]

    print(f"Executing tests in: {Colors.BLUE}{TESTS_DIR}{Colors.RESET}\n")

    try:
        # BATS сам выведет результат в stdout/stderr
        result = subprocess.run(cmd)

        if result.returncode == 0:
            print(f"\n{Colors.GREEN}✔ All Systems Operational{Colors.RESET}")
            sys.exit(0)
        else:
            print(f"\n{Colors.RED}✘ Issues Detected{Colors.RESET}")
            sys.exit(1)

    except Exception as e:
        print(f"{Colors.RED}Execution Error: {e}{Colors.RESET}")
        sys.exit(1)


if __name__ == "__main__":
    main()
