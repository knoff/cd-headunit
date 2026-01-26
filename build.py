#!/usr/bin/env python3
import argparse
import os
import subprocess
import json
import hashlib
import sys
import shutil
from pathlib import Path

# --- КОНФИГУРАЦИЯ ---
IMAGE_NAME = "headunit-builder"
DEFAULT_INPUT_IMAGE = "2025-11-24-raspios-trixie-arm64-lite.img"
OUTPUT_DIR = Path("builder/output")
UPDATES_DIR = OUTPUT_DIR / "updates"

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

def run_cmd(cmd, cwd=None, capture=False, env=None):
    """Надежный запуск системных команд."""
    try:
        res = subprocess.run(
            cmd,
            cwd=cwd,
            shell=True,
            check=True,
            text=True,
            capture_output=capture,
            env={**os.environ, **(env or {})}
        )
        return res.stdout.strip() if capture else True
    except subprocess.CalledProcessError as e:
        log(f"Error executing: {cmd}", Colors.RED)
        if e.stdout: print(e.stdout)
        if e.stderr: print(e.stderr)
        sys.exit(1)

def get_git_version():
    return run_cmd("git describe --tags --always --dirty", capture=True) or "unknown"

def get_changed_files():
    """Возвращает список измененных файлов через Git."""
    run_cmd("git fetch --tags", capture=True) # На всякий случай
    # Проверяем и stage, и unstage файлы
    dirty = run_cmd("git status --porcelain", capture=True)
    if dirty:
        return [line[3:] for line in dirty.split('\n') if line]
    # Если грязных файлов нет, смотрим последний коммит
    last_commit = run_cmd("git diff-tree --no-commit-id --name-only -r HEAD", capture=True)
    return last_commit.split('\n') if last_commit else []

def get_targets(args):
    """Определяет, какие слои нужно собирать."""
    if args.force and not (args.app or args.services or args.os or args.components):
        return {"APP", "SERVICES", "OS"}

    requested = set()
    if args.app: requested.add("APP")
    if args.services: requested.add("SERVICES")
    if args.components:
        requested.add("APP")
        requested.add("SERVICES")
    if args.os: requested.add("OS")

    # Авто-детект, если ничего не указано
    if not requested:
        files = get_changed_files()
        os_triggers = ["builder/", "system/", "headunit.conf", "build.py"]

        if any(f.startswith("src/") for f in files): requested.add("APP")
        if any(f.startswith("services/") or f.startswith("external/cd-protocol/") for f in files):
            requested.add("SERVICES")
        if any(any(f.startswith(trig) for trig in os_triggers) for f in files):
            requested.add("OS")

        if not requested:
            return set()
        return requested

    # Если цели указаны явно, но нет --force, проверяем изменения
    if not args.force:
        files = get_changed_files()
        final = set()
        if "APP" in requested and any(f.startswith("src/") for f in files): final.add("APP")
        if "SERVICES" in requested and any(f.startswith("services/") or f.startswith("external/cd-protocol/") for f in files):
            final.add("SERVICES")
        if "OS" in requested:
            os_triggers = ["builder/", "system/", "headunit.conf", "build.py"]
            if any(any(f.startswith(trig) for trig in os_triggers) for f in files):
                final.add("OS")
        return final

    return requested

# --- ЭТАПЫ СБОРКИ ---

def package_artifact(source_dir, component_name, version):
    """Упаковывает компонент в tar.gz через Docker."""
    log(f"\n>>> [PACK] Packaging {component_name} v{version}...", Colors.CYAN)

    UPDATES_DIR.mkdir(parents=True, exist_ok=True)
    tar_name = f"headunit-{component_name}-v{version}.tar.gz"

    # Формируем скрипт для упаковки
    bash_script = f"""
set -e
echo "   -> [DOCKER] Building {component_name} tarball..."
STAGING="/tmp/pkg/{version}"
mkdir -p "$STAGING"
cp -r "/workspace/{source_dir}"/* "$STAGING/"

# Cleanup frontend junk
if [ -d "$STAGING/frontend" ] && [ -d "$STAGING/frontend/dist" ]; then
    echo "   -> [DOCKER] Preserving frontend/dist..."
    mv "$STAGING/frontend/dist" /tmp/dist_save
    rm -rf "$STAGING/frontend"/*
    mv /tmp/dist_save "$STAGING/frontend/dist"
fi

chmod -R 755 "$STAGING"
find "$STAGING" -type f -exec chmod 644 {{}} \\;

cd /tmp/pkg
tar -czf "/workspace/{UPDATES_DIR.as_posix()}/{tar_name}" "{version}"
cd "/workspace/{UPDATES_DIR.as_posix()}"
sha256sum "{tar_name}" > "{tar_name}.sha256"
rm -rf /tmp/pkg
"""

    # Запуск через stdin (Python делает это надежно)
    # Принудительно очищаем от \r и передаем как bytes, чтобы избежать Windows-автозамены \n -> \r\n
    subprocess.run(
        ["docker", "run", "--rm", "-i", "-v", f"{os.getcwd()}:/workspace", IMAGE_NAME, "/bin/bash"],
        input=bash_script.replace('\r', '').encode('utf-8'),
        check=True
    )
    log(f" -> Artifact OK: {UPDATES_DIR}/{tar_name}", Colors.GREEN)

def build_app(args):
    log("\n>>> [BUILD] Application Layer (src/)...", Colors.MAGENTA)
    manifest_path = Path("src/manifest.json")
    if not manifest_path.exists():
        manifest_path.write_text(json.dumps({
            "component": "app", "version": "0.1.0",
            "dependencies": {"services": ">=0.1.0"}
        }, indent=2))

    with open(manifest_path) as f:
        ver = json.load(f).get("version", "0.0.0")

    package_artifact("src", "app", ver)

def build_services(args):
    log("\n>>> [BUILD] Services Layer (services/)...", Colors.MAGENTA)
    lib_dir = Path("services/lib")
    lib_dir.mkdir(parents=True, exist_ok=True)

    if Path("services/requirements.txt").exists():
        log(" -> Installing Shared Dependencies...", Colors.GRAY)
        run_cmd(
            f"docker run --rm -v {os.getcwd()}:/workspace {IMAGE_NAME} "
            f"pip3 install -r /workspace/services/requirements.txt --target /workspace/services/lib "
            f"--upgrade --platform manylinux2014_aarch64 --only-binary=:all:"
        )

    proto_src = Path("external/cd-protocol/src/python")
    if proto_src.exists():
        log(" -> Injecting cd-protocol...", Colors.GRAY)
        shutil.copytree(proto_src, lib_dir / "cd_protocol", dirs_exist_ok=True)

    with open("services/manifest.json") as f:
        ver = json.load(f).get("version", "0.0.0")

    package_artifact("services", "services", ver)

def build_os(args, version):
    log("\n>>> [BUILD] OS Image (System Layer)...", Colors.YELLOW)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    target_file = OUTPUT_DIR / f"headunit-{version}-{args.mode}.img"

    docker_args = [
        "docker", "run", "--rm", "--privileged",
        "-v", f"{os.getcwd()}:/workspace",
        "-e", f"INPUT_IMAGE={args.input_image}",
        "-e", f"BUILD_VERSION={version}",
        "-e", f"TARGET_FILENAME={target_file.as_posix()}",
        IMAGE_NAME, "/bin/bash"
    ]

    if args.interactive:
        subprocess.run(docker_args + ["-it"])
    else:
        subprocess.run(docker_args + ["builder/build.sh", args.mode], check=True)
        if not args.tests_skip:
            log("\n>>> [TEST] Running Image Verification...", Colors.MAGENTA)
            run_cmd(
                f"docker run --rm --privileged -v {os.getcwd()}:/workspace {IMAGE_NAME} "
                f"/bin/bash /workspace/builder/lib/test_runner.sh --mode image "
                f"--target /workspace/{target_file.as_posix()}"
            )

# --- МЕЙН ---

def main():
    parser = argparse.ArgumentParser(
        description="HeadUnit OS Smart Builder",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n  python build.py --force\n  python build.py --app --force\n  python build.py --os"
    )

    # Цели
    group_target = parser.add_argument_group("Targets")
    group_target.add_argument("--app", action="store_true", help="Build Application layer")
    group_target.add_argument("--services", action="store_true", help="Build Services layer")
    group_target.add_argument("--components", action="store_true", help="Build both App and Services")
    group_target.add_argument("--os", action="store_true", help="Build OS Image")

    # Модификаторы и опции
    parser.add_argument("-f", "--force", action="store_true", help="Force build (ignore git changes)")
    parser.add_argument("-m", "--mode", choices=['dev', 'prod'], default='dev', help="Build mode")
    parser.add_argument("-i", "--input-image", default=DEFAULT_INPUT_IMAGE, help="Base image file")
    parser.add_argument("--tests-skip", action="store_true", help="Skip verification tests")
    parser.add_argument("--interactive", action="store_true", help="Run interactive shell in builder")
    parser.add_argument("--test", metavar="PATH", help="Run tests for specific image or 'unit'")

    args = parser.parse_args()

    # Специальный режим теста
    if args.test:
        if args.test == "unit":
            run_cmd(f"docker run --rm -v {os.getcwd()}:/workspace {IMAGE_NAME} /bin/bash /workspace/builder/lib/test_runner.sh --mode unit")
        else:
            log(f">>> [TEST] Verifying image: {args.test}", Colors.MAGENTA)
            run_cmd(f"docker run --rm --privileged -v {os.getcwd()}:/workspace {IMAGE_NAME} /bin/bash /workspace/builder/lib/test_runner.sh --mode image --target /workspace/{args.test}")
        sys.exit(0)

    log(">>> [INIT] Preparing Builder Environment...", Colors.GRAY)
    run_cmd(f"docker build -t {IMAGE_NAME} -f builder/Dockerfile .")

    version = get_git_version()
    targets = get_targets(args)

    if not targets:
        log("No changes detected. Use --force to rebuild.", Colors.GRAY)
        sys.exit(0)

    log("\n" + "="*40, Colors.CYAN)
    log(f" Pipeline Targets: {', '.join(targets)}", Colors.CYAN)
    log("="*40)

    if "APP" in targets: build_app(args)
    if "SERVICES" in targets: build_services(args)
    if "OS" in targets: build_os(args, version)

if __name__ == "__main__":
    # Исправление для Windows ANSI цветов
    if sys.platform == "win32":
        os.system('color')
    main()
