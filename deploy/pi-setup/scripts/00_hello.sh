#!/bin/bash
LOG_FILE="${BOOT_SCRIPT_LOG:-${1:-/dev/null}}"
log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" | logger -t "$(basename "$0")"; }

log "Hello from $(hostname)"
