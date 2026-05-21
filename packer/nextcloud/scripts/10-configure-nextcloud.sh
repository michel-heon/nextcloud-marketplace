#!/usr/bin/env bash
# 10-configure-nextcloud.sh — Set file permissions and prepare directory structure
# NOTE: occ maintenance:install is NOT run here; it is handled by the first-boot service.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

NC_WEBROOT="/var/www/nextcloud"
NC_DATA_DIR="/var/nextcloud-data"

log_section "10 — Configure Nextcloud directories and permissions"

# Create the external data directory (outside webroot)
if [[ ! -d "${NC_DATA_DIR}" ]]; then
  log_info "Creating Nextcloud data directory at ${NC_DATA_DIR}"
  mkdir -p "${NC_DATA_DIR}"
fi

log_info "Setting ownership on webroot"
chown -R www-data:www-data "${NC_WEBROOT}"

log_info "Setting ownership on data directory"
chown -R www-data:www-data "${NC_DATA_DIR}"

log_info "Setting directory permissions on webroot (750)"
find "${NC_WEBROOT}" -type d -exec chmod 750 {} \;

log_info "Setting file permissions on webroot (640)"
find "${NC_WEBROOT}" -type f -exec chmod 640 {} \;

# occ must be executable by www-data
log_info "Making occ executable"
chmod +x "${NC_WEBROOT}/occ"

log_info "Setting data directory permissions (750)"
chmod 750 "${NC_DATA_DIR}"

log_info "Setting ACL for www-data on data directory"
setfacl -R -m u:www-data:rwx "${NC_DATA_DIR}" || true

log_info "Creating Nextcloud log directory"
mkdir -p /var/log/nextcloud
chown www-data:www-data /var/log/nextcloud
chmod 750 /var/log/nextcloud

log_section "10 — Nextcloud directory configuration complete"
