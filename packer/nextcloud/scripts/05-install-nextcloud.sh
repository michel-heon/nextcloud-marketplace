#!/usr/bin/env bash
# 05-install-nextcloud.sh — Download, verify, and extract Nextcloud files
# Environment variable: NC_VERSION (default: 31.0.2)
# NOTE: Does NOT run occ install — that is handled by the first-boot service.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

NC_VERSION="${NC_VERSION:-31.0.2}"
NC_WEBROOT="/var/www/nextcloud"
NC_DOWNLOAD_URL="https://download.nextcloud.com/server/releases/nextcloud-${NC_VERSION}.zip"
NC_CHECKSUM_URL="${NC_DOWNLOAD_URL}.sha256"
NC_TMP_DIR="/tmp/nextcloud-install"

log_section "05 — Install Nextcloud ${NC_VERSION}"

# Create nextcloud system user if it doesn't exist
if ! id -u nextcloud >/dev/null 2>&1; then
  log_info "Creating nextcloud system user"
  useradd --system --no-create-home --shell /usr/sbin/nologin nextcloud
fi

# Download and verify
if [[ -d "${NC_WEBROOT}/lib" ]]; then
  log_info "Nextcloud is already extracted at ${NC_WEBROOT} — skipping download"
else
  mkdir -p "${NC_TMP_DIR}"
  cd "${NC_TMP_DIR}"

  log_info "Downloading Nextcloud ${NC_VERSION}"
  curl -fsSL --progress-bar "${NC_DOWNLOAD_URL}" -o "nextcloud-${NC_VERSION}.zip"

  log_info "Downloading SHA256 checksum"
  curl -fsSL "${NC_CHECKSUM_URL}" -o "nextcloud-${NC_VERSION}.zip.sha256"

  log_info "Verifying checksum"
  grep "nextcloud-${NC_VERSION}\.zip$" "nextcloud-${NC_VERSION}.zip.sha256" | sha256sum -c -

  log_info "Extracting Nextcloud to ${NC_WEBROOT}"
  mkdir -p /var/www
  unzip -q "nextcloud-${NC_VERSION}.zip" -d /var/www/
  # unzip creates /var/www/nextcloud/

  log_info "Cleaning up download"
  rm -rf "${NC_TMP_DIR}"
fi

log_section "05 — Nextcloud files installed at ${NC_WEBROOT}"
