#!/bin/bash
LOG_FILE="${BOOT_SCRIPT_LOG:-${1:-/dev/null}}"
log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" | logger -t "$(basename "$0")"; }

sudo locale-gen en_GB.UTF-8
sudo update-locale LANG=en_GB.UTF-8 LC_ALL=en_GB.UTF-8
