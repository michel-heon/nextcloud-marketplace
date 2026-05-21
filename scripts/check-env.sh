#!/usr/bin/env bash
# scripts/check-env.sh — Verify required environment variables before build
# Usage: bash scripts/check-env.sh

set -euo pipefail

required_vars=(
  AZURE_SUBSCRIPTION_ID
  AZURE_TENANT_ID
  AZURE_CLIENT_ID
  AZURE_CLIENT_SECRET
  AZURE_LOCATION
  BUILD_RESOURCE_GROUP
  GALLERY_RESOURCE_GROUP
  GALLERY_NAME
  GALLERY_IMAGE_NAME
  IMAGE_VERSION
)

missing=0
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "[ERROR] Missing required variable: ${var}" >&2
    missing=$((missing + 1))
  fi
done

if [[ $missing -gt 0 ]]; then
  echo "" >&2
  echo "[ERROR] ${missing} required variable(s) missing." >&2
  echo "        Copy env/.env.example to env/.env and fill in the values." >&2
  exit 1
fi

echo "[OK] All required environment variables are set."
