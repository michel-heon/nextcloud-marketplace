#!/usr/bin/env bash
# 99-sysprep.sh — Clean up temporary files and deprovision the VM image
# This must run last — it removes SSH host keys and the Packer SSH user.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

PHP_VERSION="${PHP_VERSION:-8.3}"

log_section "99 — Sysprep and deprovision"

log_info "Stopping services before cleanup"
systemctl stop nginx || true
systemctl stop "php${PHP_VERSION}-fpm" || true
systemctl stop redis-server || true

log_info "Cleaning apt cache"
apt-get clean
apt-get autoremove -y -qq
rm -rf /var/lib/apt/lists/*

log_info "Removing temp files"
rm -rf /tmp/* /var/tmp/*

log_info "Clearing logs"
find /var/log -type f -name "*.log" -writable -exec truncate --size=0 {} \;
find /var/log -type f -name "*.gz" -delete
journalctl --rotate
journalctl --vacuum-time=1s

log_info "Clearing shell history"
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/packer/.bash_history 2>/dev/null || true

log_info "Removing residual SSH authorized_keys (policy 200.5 — image cleanliness)"
find /root /home -name 'authorized_keys' -exec truncate -s 0 {} \; 2>/dev/null || true

log_info "Removing SSH host keys (will be regenerated on first boot)"
rm -f /etc/ssh/ssh_host_*

log_info "Removing cloud-init instance data"
cloud-init clean --logs

log_info "Deprovisioning with waagent"
# -force skips confirmation; +user removes the provisioning user created by Packer
waagent -deprovision+user -force

log_section "99 — Sysprep complete — image is ready"
