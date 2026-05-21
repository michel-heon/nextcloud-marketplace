#!/usr/bin/env bash
# 11-configure-security.sh — UFW, fail2ban, and unattended-upgrades hardening

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

log_section "11 — Configure security (UFW, fail2ban, unattended-upgrades)"

# --- UFW ---
log_info "Configuring UFW firewall rules"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp  comment "SSH"
ufw allow 80/tcp  comment "HTTP (redirect to HTTPS)"
ufw allow 443/tcp comment "HTTPS"
ufw --force enable

log_info "UFW status:"
ufw status verbose

# --- fail2ban ---
log_info "Configuring fail2ban"

cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled  = true
port     = ssh
filter   = sshd
maxretry = 5
bantime  = 3600
findtime = 600
EOF

cat > /etc/fail2ban/jail.d/nextcloud.local <<'EOF'
[nextcloud]
enabled  = true
port     = http,https
filter   = nextcloud
logpath  = /var/log/nextcloud/nextcloud.log
maxretry = 10
bantime  = 3600
findtime = 600
EOF

# fail2ban filter for Nextcloud
cat > /etc/fail2ban/filter.d/nextcloud.conf <<'EOF'
[Definition]
_groupsre = (?:(?:,?\s*"\w+":(?:"[^"]+"|\w+))*)
failregex = ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Login failed:
            ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Trusted domain error.
ignoreregex =
EOF

log_info "Enabling fail2ban on boot"
systemctl enable fail2ban
systemctl restart fail2ban

# --- unattended-upgrades ---
log_info "Configuring unattended-upgrades for security updates"

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# --- SSH hardening ---
log_info "Hardening SSH configuration"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
echo "AllowAgentForwarding no" >> /etc/ssh/sshd_config

# Validate SSH config before reloading
sshd -t
systemctl reload ssh || systemctl reload sshd

log_section "11 — Security configuration complete"
