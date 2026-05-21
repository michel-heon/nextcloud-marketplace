#!/usr/bin/env bash
# 02-install-php.sh — Install PHP-FPM and required Nextcloud extensions
# Environment variable: PHP_VERSION (default: 8.3)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

PHP_VERSION="${PHP_VERSION:-8.3}"

log_section "02 — Install PHP ${PHP_VERSION}-FPM"

if is_installed "php${PHP_VERSION}-fpm"; then
  log_info "PHP ${PHP_VERSION}-FPM is already installed — skipping"
else
  log_info "Adding ondrej/php PPA for PHP ${PHP_VERSION}"
  add-apt-repository -y ppa:ondrej/php
  wait_for_apt
  apt-get update -qq

  log_info "Installing PHP ${PHP_VERSION}-FPM and Nextcloud extensions"
  apt_install \
    "php${PHP_VERSION}-fpm" \
    "php${PHP_VERSION}-cli" \
    "php${PHP_VERSION}-common" \
    "php${PHP_VERSION}-pgsql" \
    "php-redis" \
    "php${PHP_VERSION}-gd" \
    "php${PHP_VERSION}-curl" \
    "php${PHP_VERSION}-xml" \
    "php${PHP_VERSION}-zip" \
    "php${PHP_VERSION}-mbstring" \
    "php${PHP_VERSION}-bz2" \
    "php${PHP_VERSION}-intl" \
    "php${PHP_VERSION}-bcmath" \
    "php${PHP_VERSION}-gmp" \
    "php-imagick" \
    "php${PHP_VERSION}-apcu" \
    "php${PHP_VERSION}-opcache" \
    "php${PHP_VERSION}-ldap" \
    "php${PHP_VERSION}-imap" \
    "php-smbclient" \
    imagemagick

  log_info "Enabling PHP-FPM on boot"
  systemctl enable "php${PHP_VERSION}-fpm"

  log_info "PHP version: $(php -r 'echo PHP_VERSION;')"
fi

log_section "02 — PHP ${PHP_VERSION}-FPM installation complete"
