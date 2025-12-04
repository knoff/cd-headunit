#!/usr/bin/env bash
set -euo pipefail
BOOT="/boot"; [ -d /boot/firmware ] && BOOT="/boot/firmware"
echo "start: components (Docker, каталоги)"

# Docker (пример для Raspberry Pi OS)
if ! command -v docker >/dev/null 2>&1; then
  echo "install docker"
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker "${USER_NAME:-cdreborn}" || true
fi
systemctl enable docker || true
systemctl restart docker || true

echo "done"
exit 0
