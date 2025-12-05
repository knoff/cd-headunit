#!/bin/bash

# Цвета для вывода
c_reset='\033[0m'
c_green='\033[1;32m'
c_yellow='\033[1;33m'
c_red='\033[1;31m'
c_cyan='\033[1;36m'

log_info() { echo -e "${c_green}[INFO]${c_reset} $1"; }
log_warn() { echo -e "${c_yellow}[WARN]${c_reset} $1"; }
log_error() { echo -e "${c_red}[ERROR]${c_reset} $1"; }
log_step() { echo -e "\n${c_cyan}>>> STAGE: $1${c_reset}"; }

# Функция для завершения при ошибке (можно использовать с trap)
die() {
    log_error "$1"
    exit 1
}
