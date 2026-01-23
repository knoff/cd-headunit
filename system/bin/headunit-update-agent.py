#!/usr/bin/env python3
import os
import sys
import argparse
import hashlib
import tarfile
import json
import shutil
import subprocess
import time

# --- CONFIGURATION ---
UPDATES_ROOT = "/data/components"
LOCK_FILE = "/run/headunit/update.lock"
SHA_EXT = ".sha256"

# --- HELPERS ---

def log(msg, level="INFO"):
    print(f"[{level}] {msg}")

def fail(msg, code=1):
    log(msg, "ERROR")
    sys.exit(code)

def calculate_sha256(filepath):
    sha = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            sha.update(chunk)
    return sha.hexdigest()

def acquire_lock():
    if os.path.exists(LOCK_FILE):
        fail(f"Update already in progress! Lock file exists: {LOCK_FILE}")
    try:
        with open(LOCK_FILE, "w") as f:
            f.write(str(os.getpid()))
    except IOError as e:
        fail(f"Could not acquire lock: {e}")

def release_lock():
    if os.path.exists(LOCK_FILE):
        os.remove(LOCK_FILE)

# --- CORE LOGIC ---

def validate_package(filepath):
    log(f"Validating package: {filepath}...")

    if not os.path.exists(filepath):
        fail("File not found.")

    # 1. Checksum
    sha_file = filepath + SHA_EXT
    if not os.path.exists(sha_file):
        fail(f"Checksum file missing: {sha_file}")

    expected_sha = ""
    with open(sha_file, "r") as f:
        expected_sha = f.read().strip().split()[0] # Handle "hash  filename" format

    actual_sha = calculate_sha256(filepath)

    if expected_sha != actual_sha:
        fail(f"Checksum mismatch! Expected: {expected_sha}, Actual: {actual_sha}")

    log("Checksum OK.")

    # 2. Structure & Manifest
    try:
        with tarfile.open(filepath, "r:gz") as tar:
            # Check for manifest.json
            # Note: We look for manifest.json either in root or inside the single top-level dir
            manifest_member = None
            for m in tar.getmembers():
                if m.name.endswith("/manifest.json") or m.name == "manifest.json":
                    manifest_member = m
                    break

            if not manifest_member:
                fail("manifest.json not found in archive!")

            f = tar.extractfile(manifest_member)
            manifest = json.load(f)

            comp = manifest.get("component")
            ver = manifest.get("version")

            if not comp or not ver:
                fail("Invalid manifest: missing 'component' or 'version'")

            log(f"Package valid. Component: {comp}, Version: {ver}")
            return comp, ver

    except tarfile.TarError as e:
        fail(f"Invalid tar archive: {e}")
    except json.JSONDecodeError as e:
        fail(f"Invalid manifest JSON: {e}")

def install_package(filepath, component, version):
    log(f"Installing {component} v{version}...")

    target_dir = os.path.join(UPDATES_ROOT, component, version)

    # Clean target
    if os.path.exists(target_dir):
        log("Removing existing version directory...")
        shutil.rmtree(target_dir)

    os.makedirs(target_dir, exist_ok=True)

    # Extract
    try:
        with tarfile.open(filepath, "r:gz") as tar:

            # Logic to handle if archive has root folder or not
            # If all members start with the same prefix, we strip it?
            # Or currently per spec: "Archive contains raw files or a folder"
            # Let's rely on standard extraction and if it creates a subdir, we might need to handle it.
            # BUT: Spec said "Archive contains raw files. Unpacker creates version folder."
            # So we extract directly into target_dir.

            # Security: avoid zip slips (basic check)
            def is_safe_member(member):
                return not (member.name.startswith("/") or ".." in member.name)

            safe_members = [m for m in tar.getmembers() if is_safe_member(m)]
            tar.extractall(path=target_dir, members=safe_members)

            # If the archive wrapped everything in a single folder 'v1.0.0/', move contents up?
            # Let's verify manifest location in target
            if not os.path.exists(os.path.join(target_dir, "manifest.json")):
                # Check subdirs
                subdirs = [d for d in os.listdir(target_dir) if os.path.isdir(os.path.join(target_dir, d))]
                if len(subdirs) == 1:
                    subdir_path = os.path.join(target_dir, subdirs[0])
                    if os.path.exists(os.path.join(subdir_path, "manifest.json")):
                        log(f"Detected nested structure. Moving contents from {subdirs[0]} to root...")
                        for item in os.listdir(subdir_path):
                            shutil.move(os.path.join(subdir_path, item), target_dir)
                        os.rmdir(subdir_path)

    except Exception as e:
        fail(f"Extraction failed: {e}")

    log("Installation successful.")

def system_reboot():
    log("Rebooting system...")
    subprocess.run(["reboot"])

# --- MAIN ---

def main():
    parser = argparse.ArgumentParser(description="HeadUnit Update Agent")
    parser.add_argument("--file", help="Path to update package (.tar.gz)")
    parser.add_argument("--scan", help="Directory to scan for updates")
    parser.add_argument("--no-reboot", action="store_true", help="Skip system reboot after install")
    args = parser.parse_args()

    if not args.file and not args.scan:
        parser.print_help()
        sys.exit(1)

    try:
        target_file = args.file

        # Simple scan logic: find first valid pair
        if args.scan:
            if not os.path.exists(args.scan):
                fail(f"Scan directory not found: {args.scan}")

            candidates = [f for f in os.listdir(args.scan) if f.endswith(".tar.gz")]
            if not candidates:
                log("No updates found.")
                sys.exit(0)

            # Just pick the first one for now (or sort?)
            target_file = os.path.join(args.scan, candidates[0])
            log(f"Found candidate: {target_file}")

        acquire_lock()

        comp, ver = validate_package(target_file)
        install_package(target_file, comp, ver)

        # Cleanup source file if it was a drop?
        # For USB we don't delete. For /data/incoming_updates we SHOULD delete.
        if "/data/incoming_updates" in os.path.abspath(target_file):
            log("Cleaning up dropped update file...")
            os.remove(target_file)
            sha_file = target_file + SHA_EXT
            if os.path.exists(sha_file):
                os.remove(sha_file)

        # Sync disk
        subprocess.run(["sync"])

        # Reboot?
        if not args.no_reboot:
            system_reboot()
        else:
            log("Skipping reboot (--no-reboot set).")

    except Exception as e:
        log(f"Unexpected error: {e}", "CRITICAL")
        sys.exit(1)
    finally:
        release_lock()

if __name__ == "__main__":
    main()
