#!/usr/bin/env bash
# 07-configure-php.sh — Deploy PHP-FPM configuration for Nextcloud
# Environment variable: PHP_VERSION (default: 8.3)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

PHP_VERSION="${PHP_VERSION:-8.3}"
PHP_FPM_CONF_DIR="/etc/php/${PHP_VERSION}/fpm"
PHP_CLI_CONF_DIR="/etc/php/${PHP_VERSION}/cli"

log_section "07 — Configure PHP ${PHP_VERSION}-FPM"

log_info "Deploying PHP ini overrides"
install -m 644 /tmp/config/php/nextcloud.ini \
  "${PHP_FPM_CONF_DIR}/conf.d/99-nextcloud.ini"
install -m 644 /tmp/config/php/nextcloud.ini \
  "${PHP_CLI_CONF_DIR}/conf.d/99-nextcloud.ini"

log_info "Deploying PHP-FPM pool configuration"
install -m 644 /tmp/config/php/www.conf \
  "${PHP_FPM_CONF_DIR}/pool.d/www.conf"

log_info "Setting PHP version to ${PHP_VERSION} in pool configuration"
sed -i "s|php8.3-fpm|php${PHP_VERSION}-fpm|g" "${PHP_FPM_CONF_DIR}/pool.d/www.conf"

log_info "Setting PHP-FPM socket ownership"
# Socket will be created by php-fpm at runtime; ensure the run directory exists
mkdir -p "/run/php"
chown root:root "/run/php"

log_info "Testing PHP-FPM configuration"
"php-fpm${PHP_VERSION}" -t

log_info "Restarting PHP-FPM"
systemctl restart "php${PHP_VERSION}-fpm"

log_section "07 — PHP ${PHP_VERSION}-FPM configuration complete"
