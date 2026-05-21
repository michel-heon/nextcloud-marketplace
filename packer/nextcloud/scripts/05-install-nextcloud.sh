#!/usr/bin/env bash
# 05-install-nextcloud.sh — Download, verify, and extract Nextcloud files
# Environment variables:
#   NC_VERSION            (default: 33.0.3)
#   BLOB_STORAGE_BASE_URL — blob-first cache URL; empty string = disabled (ADR-616)
# NOTE: Does NOT run occ install — that is handled by the first-boot service.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

NC_VERSION="${NC_VERSION:-33.0.3}"
BLOB_STORAGE_BASE_URL="${BLOB_STORAGE_BASE_URL:-}"
NC_WEBROOT="/var/www/nextcloud"
NC_DOWNLOAD_URL="https://download.nextcloud.com/server/releases/nextcloud-${NC_VERSION}.zip"
NC_CHECKSUM_URL="${NC_DOWNLOAD_URL}.sha256"
NC_TMP_DIR="/tmp/nextcloud-install"

# ------------------------------------------------------------
# download_package <blob_filename> <source_url> <output_file>
# Tries blob cache first (if BLOB_STORAGE_BASE_URL is set),
# then falls back to the authoritative source URL.
# ------------------------------------------------------------
download_package() {
  local blob_filename="$1"
  local source_url="$2"
  local output_file="$3"

  if [[ -n "${BLOB_STORAGE_BASE_URL}" ]]; then
    local blob_url="${BLOB_STORAGE_BASE_URL}/${blob_filename}"
    log_info ">>> Trying blob cache: ${blob_url}"
    if wget -q --spider "${blob_url}" 2>/dev/null && wget -q "${blob_url}" -O "${output_file}"; then
      log_info ">>> Downloaded from blob cache"
      return 0
    else
      log_info ">>> Blob unavailable, falling back to source..."
    fi
  fi

  log_info ">>> Downloading from source: ${source_url}"
  wget -q "${source_url}" -O "${output_file}"
}

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
  download_package "nextcloud-${NC_VERSION}.zip" "${NC_DOWNLOAD_URL}" "nextcloud-${NC_VERSION}.zip"

  log_info "Downloading SHA256 checksum"
  wget -q "${NC_CHECKSUM_URL}" -O "nextcloud-${NC_VERSION}.zip.sha256"

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
