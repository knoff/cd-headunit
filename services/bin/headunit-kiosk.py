#!/usr/bin/env python3
import os
import subprocess
import time
import sys
import socket

def wait_for_backend():
    """Wait for the backend to be available on port 8000."""
    attempts = 0
    print("[INIT] Checking backend availability on localhost:8000...")
    while True:
        try:
            with socket.create_connection(("127.0.0.1", 8000), timeout=1):
                print("[INIT] Backend is UP.")
                return
        except (socket.timeout, ConnectionRefusedError):
            if attempts % 5 == 0:
                print(f"[INIT] Waiting for Backend... (attempt {attempts})")
            time.sleep(1)
            attempts += 1
            if attempts > 60:
                print("[ERROR] Timeout: Backend did not start in 60 seconds.")
                sys.exit(1)

def get_chromium_command():
    flags = [
        "--kiosk",
        "--no-first-run",
        "--noerrdialogs",
        "--disable-infobars",
        "--autoplay-policy=no-user-gesture-required",
        "--check-for-update-interval=31536000",
        "--disable-pinch",
        "--overscroll-history-navigation=0",
        "--remote-debugging-port=9222",
        "--remote-debugging-address=0.0.0.0",
        "--remote-allow-origins=*",
        "--enable-features=UseOzonePlatform",
        "--ozone-platform=wayland",
        "--user-data-dir=/data/app/chromium",
        "--disk-cache-dir=" + os.environ.get("XDG_RUNTIME_DIR", "/tmp") + "/chromium_cache",
        "--disk-cache-size=1048576", # 1MB limit (effectively disabled)
        "--no-sandbox",
        "--disable-gpu-sandbox",
        "--ignore-gpu-blocklist",
        "--enable-gpu-rasterization",
        "--enable-zero-copy",
        # Performance tweaks for RPi 4
        "--canvas-oop-rasterization",
        "--disable-features=Translate,OptimizationHints,MediaRouter,DialMediaRouteProvider",
    ]

    return ["chromium"] + flags + ["http://localhost:8000"]

def main():
    # 1. Setup Environment
    uid = os.getuid()
    xdg_runtime = f"/run/user/{uid}"

    print(f"[KIOSK] Starting for UID {uid}")
    print(f"[KIOSK] Setting XDG_RUNTIME_DIR to {xdg_runtime}")

    if not os.path.exists(xdg_runtime):
        print(f"[WARN] {xdg_runtime} does not exist! Chromium might fail to connect to Wayland.")

    # 2. Wait for readiness
    wait_for_backend()

    # 3. Ensure user data dir on persistent storage
    os.makedirs("/data/app/chromium", exist_ok=True)

    # 3b. Clean up stale locks (Fix for "Profile in use" error 21)
    # Since we use persistent storage, a hard reboot can leave lock files.
    # We are the only instance, so it's safe to clear them.
    for lock_file in ["SingletonLock", "SingletonSocket", "SingletonCookie"]:
        try:
            path = os.path.join("/data/app/chromium", lock_file)
            if os.path.islink(path) or os.path.exists(path):
                print(f"[KIOSK] removing stale lock: {path}")
                os.remove(path)
        except Exception as e:
            print(f"[WARN] Failed to remove {lock_file}: {e}")

    # 4. Launch
    chrome_cmd = get_chromium_command()
    # Cage is our minimal Wayland compositor
    cmd = ["cage", "-s", "--"] + chrome_cmd

    print(f"[KIOSK] Executing: {' '.join(cmd)}")

    env = os.environ.copy()
    env["XDG_RUNTIME_DIR"] = xdg_runtime

    # Force GPU renderer for wlroots if needed
    env["WLR_RENDERER"] = "gles2"

    try:
        process = subprocess.Popen(
            cmd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )

        # Stream logs to systemd journal
        for line in process.stdout:
            print(f"[BROWSER] {line.strip()}")

        process.wait()
        if process.returncode != 0:
            print(f"[ERROR] Kiosk exited with code {process.returncode}")
            sys.exit(process.returncode)

    except Exception as e:
        print(f"[ERROR] Kiosk launcher error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
