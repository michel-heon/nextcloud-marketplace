#!/usr/bin/env bash
# 01-install-nginx.sh — Install NGINX from the official Ubuntu repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

log_section "01 — Install NGINX"

if is_installed nginx; then
  log_info "NGINX is already installed — skipping"
else
  log_info "Installing NGINX"
  apt_install nginx

  log_info "Enabling NGINX to start on boot"
  systemctl enable nginx

  # Remove default site to avoid conflicts with Nextcloud vhost
  if [[ -f /etc/nginx/sites-enabled/default ]]; then
    log_info "Removing default NGINX site"
    rm -f /etc/nginx/sites-enabled/default
  fi

  log_info "NGINX version: $(nginx -v 2>&1)"
fi

log_section "01 — NGINX installation complete"
