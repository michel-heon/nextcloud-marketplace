#!/usr/bin/env bash
# 03-install-postgresql.sh — Install PostgreSQL from the official PGDG repository
# Environment variable: PG_VERSION (default: 16)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

PG_VERSION="${PG_VERSION:-16}"

log_section "03 — Install PostgreSQL ${PG_VERSION}"

if is_installed "postgresql-${PG_VERSION}"; then
  log_info "PostgreSQL ${PG_VERSION} is already installed — skipping"
else
  log_info "Adding PostgreSQL PGDG repository"
  install -d /usr/share/postgresql-common/pgdg
  curl -fsSL 'https://www.postgresql.org/media/keys/ACCC4CF8.asc' \
    | gpg --dearmor -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg

  echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg] \
https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

  wait_for_apt
  apt-get update -qq

  log_info "Installing PostgreSQL ${PG_VERSION}"
  apt_install \
    "postgresql-${PG_VERSION}" \
    "postgresql-client-${PG_VERSION}" \
    "postgresql-contrib-${PG_VERSION}" \
    libpq-dev

  log_info "Enabling PostgreSQL on boot"
  systemctl enable "postgresql@${PG_VERSION}-main"

  log_info "PostgreSQL version: $(pg_lsclusters)"
fi

log_section "03 — PostgreSQL ${PG_VERSION} installation complete"
