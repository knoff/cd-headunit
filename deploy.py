#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import re
from pathlib import Path

# --- КОНФИГУРАЦИЯ ---
DEFAULT_USER = "root"
DEFAULT_REMOTE_DIR = "/data/incoming_updates"
UPDATES_DIR = Path("builder/output/updates")

# Цвета для терминала
class Colors:
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    GRAY = '\033[90m'
    BOLD = '\033[1m'
    END = '\033[0m'

def log(msg, color=Colors.END):
    print(f"{color}{msg}{Colors.END}")

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

def run_cmd(cmd, check=True, shell=True):
    """Надежный запуск системных команд."""
    try:
        subprocess.run(cmd, shell=shell, check=check)
        return True
    except subprocess.CalledProcessError:
        return False

def get_ssh_opts(identity=None):
    opts = ["-o StrictHostKeyChecking=no", "-o UserKnownHostsFile=/dev/null", "-o ConnectTimeout=5"]
    if identity:
        opts.append(f"-i {identity}")
    return " ".join(opts)

def try_auth(user, target, opts):
    """Проверяет доступ без пароля."""
    cmd = f'ssh {opts} -o BatchMode=yes {user}@{target} "exit"'
    return run_cmd(cmd, check=False)

def get_updates_to_deploy(requested_components=None):
    """Находит обновления для деплоя."""
    if not UPDATES_DIR.exists():
        log(f"Updates dir {UPDATES_DIR} not found.", Colors.RED)
        sys.exit(1)

    packages = list(UPDATES_DIR.glob("*.tar.gz"))
    if not packages: return []

    # Если цели не заданы - берем последние App и Services
    if not requested_components:
        requested_components = ['app', 'services']

    latest_per_comp = {}
    for p in packages:
        match = re.search(r'headunit-(.+?)-v', p.name)
        if match:
            comp = match.group(1)
            if comp in requested_components:
                if comp not in latest_per_comp or p.stat().st_mtime > latest_per_comp[comp].stat().st_mtime:
                    latest_per_comp[comp] = p

    return list(latest_per_comp.values())

# --- ОСНОВНАЯ ЛОГИКА ---

def deploy(args):
    log(">>> [DEPLOY] HeadUnit OTA Updater", Colors.CYAN)

    # 1. Сбор всех файлов для отправки
    targets = []
    if args.app: targets.append('app')
    if args.services: targets.append('services')

    updates = []
    if args.file:
        updates = [Path(args.file)]
    else:
        updates = get_updates_to_deploy(targets)

    if not updates:
        log("No updates found to deploy.", Colors.YELLOW)
        return

    all_files = []
    for p in updates:
        all_files.append(p)
        sha = p.with_suffix(p.suffix + ".sha256")
        if sha.exists():
            all_files.append(sha)

    # 2. Настройка SSH
    ssh_opts = get_ssh_opts(args.identity)
    remote_conn = f"{args.user}@{args.target}"

    # Проверка SSH ключа
    if not try_auth(args.user, args.target, ssh_opts):
        log("\n[TIP] SSH Key not found. To stop entering passwords, run once:", Colors.YELLOW)
        log(f"   ssh-copy-id {remote_conn}", Colors.GRAY)
        log("   (Or use -i flag if you have a specific key)\n", Colors.GRAY)

    # 3. Одна команда на создание папок (1 запрос пароля)
    log(">>> [SSH] Preparing environment...", Colors.MAGENTA)
    if not run_cmd(f'ssh {ssh_opts} {remote_conn} "mkdir -p {DEFAULT_REMOTE_DIR}"'):
        log("Failed to connect. Execution aborted.", Colors.RED)
        sys.exit(1)

    # 4. Один SCP на ВСЕ файлы разом (1 запрос пароля)
    file_list_str = ' '.join([f'"{str(f)}"' for f in all_files])
    log(f"\n>>> [SCP] Uploading {len(all_files)} files...", Colors.MAGENTA)

    scp_cmd = f'scp {ssh_opts} {file_list_str} {remote_conn}:{DEFAULT_REMOTE_DIR}/'
    if run_cmd(scp_cmd):
        log(f" -> Successfully uploaded: {[f.name for f in all_files]}", Colors.GREEN)
    else:
        log("Upload failed.", Colors.RED)
        sys.exit(1)

    log("\n -> Deployment Finished.", Colors.GREEN)

    # 5. Логи
    if args.log:
        log("\n>>> [LOG] Tailing logs (Ctrl+C to stop)...", Colors.CYAN)
        try:
            subprocess.run(["ssh"] + ssh_opts.split() + ["-t", remote_conn, "journalctl -u headunit-update-monitor -u headunit-update-agent -f"])
        except KeyboardInterrupt:
            log("\nStopped.", Colors.YELLOW)

def main():
    parser = argparse.ArgumentParser(description="HeadUnit OS Deployment Tool")
    parser.add_argument("target", help="IP address / Hostname")
    parser.add_argument("-u", "--user", default=DEFAULT_USER, help="SSH User")
    parser.add_argument("-f", "--file", help="Deploy specific file only")
    parser.add_argument("--app", action="store_true", help="Deploy App only")
    parser.add_argument("--services", action="store_true", help="Deploy Services only")
    parser.add_argument("-i", "--identity", help="Private key path")
    parser.add_argument("-l", "--log", action="store_true", help="Follow logs")

    args = parser.parse_args()
    if sys.platform == "win32": os.system('color')
    deploy(args)

if __name__ == "__main__":
    main()
