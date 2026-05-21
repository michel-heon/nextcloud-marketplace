#!/usr/bin/env bash
# 06-configure-nginx.sh — Deploy the Nextcloud NGINX vhost configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

log_section "06 — Configure NGINX"

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
CONFIG_SRC="/tmp/config/nginx/nextcloud.conf"

log_info "Deploying Nextcloud NGINX vhost"
install -m 644 "${CONFIG_SRC}" "${NGINX_AVAILABLE}/nextcloud.conf"

if [[ ! -L "${NGINX_ENABLED}/nextcloud.conf" ]]; then
  ln -s "${NGINX_AVAILABLE}/nextcloud.conf" "${NGINX_ENABLED}/nextcloud.conf"
fi

# Remove default site
rm -f "${NGINX_ENABLED}/default"

log_info "Creating SSL placeholder directory"
mkdir -p /etc/ssl/nextcloud
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout /etc/ssl/nextcloud/placeholder.key \
  -out /etc/ssl/nextcloud/placeholder.crt \
  -days 3650 \
  -subj "/CN=nextcloud-placeholder" 2>/dev/null

log_info "Testing NGINX configuration"
nginx -t

log_section "06 — NGINX configuration complete"
