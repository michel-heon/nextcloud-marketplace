#!/usr/bin/env bash
# security/ufw-rules.sh
# Idempotent UFW firewall rule configuration
# Can be run standalone or invoked from the Packer provisioner (11-configure-security.sh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow overriding SSH port (default 22)
SSH_PORT="${SSH_PORT:-22}"
SSH_SOURCE_IP="${SSH_SOURCE_IP:-any}"

echo "[INFO] Configuring UFW firewall..."

# Reset to defaults non-interactively
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# SSH — restrict source IP if provided
if [[ "${SSH_SOURCE_IP}" == "any" ]]; then
    ufw allow "${SSH_PORT}/tcp" comment "SSH"
else
    ufw allow from "${SSH_SOURCE_IP}" to any port "${SSH_PORT}" proto tcp comment "SSH-restricted"
fi

# Web traffic
ufw allow 80/tcp  comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

# Enable UFW
ufw --force enable

echo "[INFO] UFW status:"
ufw status verbose
