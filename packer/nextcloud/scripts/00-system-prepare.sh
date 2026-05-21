#!/usr/bin/env bash
# 00-system-prepare.sh — System update and base package installation
# Runs first; prepares Ubuntu 24.04 for subsequent provisioning steps.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

log_section "00 — System preparation"

# Disable interactive prompts during package operations
export DEBIAN_FRONTEND=noninteractive

# Cloud-init may still be running on first boot — wait for it
if command_exists cloud-init; then
  log_info "Waiting for cloud-init to complete..."
  cloud-init status --wait || true
fi

log_info "Updating package lists"
wait_for_apt
apt-get update -qq

log_info "Upgrading installed packages"
apt-get upgrade -y -qq \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold"

log_info "Installing base packages"
apt_install \
  curl \
  wget \
  gnupg \
  lsb-release \
  apt-transport-https \
  ca-certificates \
  software-properties-common \
  unzip \
  jq \
  git \
  htop \
  vim \
  ufw \
  fail2ban \
  unattended-upgrades \
  apt-listchanges \
  acl \
  cron \
  rsync \
  openssl \
  certbot \
  python3-certbot-nginx

log_info "Enabling automatic security updates"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

log_info "Setting system timezone to UTC"
timedatectl set-timezone UTC

log_info "Setting system locale"
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

log_section "00 — System preparation complete"
