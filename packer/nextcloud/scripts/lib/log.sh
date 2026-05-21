#!/usr/bin/env bash
# packer/nextcloud/scripts/lib/log.sh
# Shared logging utilities — source this in every provisioning script
# Usage: source "$(dirname "$0")/lib/log.sh"

readonly _LOG_TS_FORMAT="%Y-%m-%d %H:%M:%S"

log_info() {
  echo "[$(date +"$_LOG_TS_FORMAT")] [INFO]  $*"
}

log_warn() {
  echo "[$(date +"$_LOG_TS_FORMAT")] [WARN]  $*" >&2
}

log_error() {
  echo "[$(date +"$_LOG_TS_FORMAT")] [ERROR] $*" >&2
}

log_section() {
  echo ""
  echo "============================================================"
  echo "[$(date +"$_LOG_TS_FORMAT")] $*"
  echo "============================================================"
}

# Wait until apt/dpkg locks are released
wait_for_apt() {
  local timeout="${1:-180}"
  local elapsed=0

  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
     || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
     || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if [[ $elapsed -ge $timeout ]]; then
      log_error "Timeout waiting for apt lock after ${timeout}s"
      return 1
    fi
    log_info "Waiting for apt lock... (${elapsed}s elapsed)"
    sleep 5
    elapsed=$((elapsed + 5))
  done
}

# Install packages, waiting for locks first
apt_install() {
  wait_for_apt
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "$@"
}

# Check if a deb package is installed
is_installed() {
  dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Check if a command is available
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Run a command only if the target condition is not already true
# Usage: idempotent_run "condition_command" "action_command"
idempotent_run() {
  local condition_cmd="$1"
  local action_cmd="$2"
  if ! eval "$condition_cmd" >/dev/null 2>&1; then
    eval "$action_cmd"
  else
    log_info "Already done, skipping: ${action_cmd}"
  fi
}
