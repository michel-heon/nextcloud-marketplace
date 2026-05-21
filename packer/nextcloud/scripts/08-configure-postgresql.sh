#!/usr/bin/env bash
# 08-configure-postgresql.sh — Create the Nextcloud database user and database
# The password will be overwritten by the first-boot setup script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

log_section "08 — Configure PostgreSQL"

NC_DB_USER="nextcloud"
NC_DB_NAME="nextcloud"
# Placeholder password — replaced at first boot
NC_DB_PASSWORD="REPLACE_AT_FIRST_BOOT"

log_info "Starting PostgreSQL"
systemctl start postgresql

log_info "Creating PostgreSQL user '${NC_DB_USER}' (if not exists)"
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${NC_DB_USER}'" \
  | grep -q 1 \
  || sudo -u postgres psql -c \
     "CREATE ROLE ${NC_DB_USER} WITH LOGIN PASSWORD '${NC_DB_PASSWORD}';"

log_info "Creating database '${NC_DB_NAME}' (if not exists)"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${NC_DB_NAME}'" \
  | grep -q 1 \
  || sudo -u postgres psql -c \
     "CREATE DATABASE ${NC_DB_NAME} OWNER ${NC_DB_USER} ENCODING 'UTF8' \
      TEMPLATE template0 LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';"

log_info "Granting privileges"
sudo -u postgres psql -c \
  "GRANT ALL PRIVILEGES ON DATABASE ${NC_DB_NAME} TO ${NC_DB_USER};"

log_info "Deploying pg_hba.conf snippet"
# Allow nextcloud user to connect via socket with md5 auth
PG_VERSION="${PG_VERSION:-16}"
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

if ! grep -q "nextcloud" "${PG_HBA}"; then
  log_info "Adding nextcloud entry to pg_hba.conf"
  echo "local   ${NC_DB_NAME}   ${NC_DB_USER}                   scram-sha-256" \
    >> "${PG_HBA}"
  systemctl reload postgresql
fi

log_section "08 — PostgreSQL configuration complete"
