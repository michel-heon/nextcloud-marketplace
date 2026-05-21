#!/usr/bin/env bash
# 04-install-redis.sh — Install Redis from the Ubuntu repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

log_section "04 — Install Redis"

if is_installed redis-server; then
  log_info "Redis is already installed — skipping"
else
  log_info "Installing Redis"
  apt_install redis-server redis-tools

  log_info "Enabling Redis on boot"
  systemctl enable redis-server

  log_info "Redis version: $(redis-server --version)"
fi

log_section "04 — Redis installation complete"
