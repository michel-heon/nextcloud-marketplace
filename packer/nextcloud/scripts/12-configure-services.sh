#!/usr/bin/env bash
# 12-configure-services.sh — Install systemd units for Nextcloud cron and first-boot setup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

log_section "12 — Configure systemd services"

NC_WEBROOT="/var/www/nextcloud"

# --- Nextcloud cron service ---
log_info "Installing nextcloud-cron systemd units"

cat > /etc/systemd/system/nextcloud-cron.service <<EOF
[Unit]
Description=Nextcloud background cron job
After=network.target postgresql.service redis-server.service

[Service]
Type=oneshot
User=www-data
ExecStart=/usr/bin/php -f ${NC_WEBROOT}/cron.php
EOF

cat > /etc/systemd/system/nextcloud-cron.timer <<'EOF'
[Unit]
Description=Run Nextcloud background cron every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=nextcloud-cron.service

[Install]
WantedBy=timers.target
EOF

systemctl enable nextcloud-cron.timer

# --- Nextcloud first-boot one-shot service ---
log_info "Installing nextcloud-first-boot systemd service"

# Install the first-boot script to a stable location
install -m 750 /tmp/config/firstboot/nc-first-boot.sh /usr/local/bin/nc-first-boot.sh
chown root:root /usr/local/bin/nc-first-boot.sh

cat > /etc/systemd/system/nextcloud-first-boot.service <<'EOF'
[Unit]
Description=Nextcloud first-boot database installation and configuration
After=network-online.target postgresql.service redis-server.service nginx.service
Wants=network-online.target
ConditionPathExists=/var/lib/cloud/instance/boot-finished
# Disable after first successful run
ConditionPathExists=!/etc/nextcloud/.first-boot-complete

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/nc-first-boot.sh
ExecStartPost=/bin/bash -c "mkdir -p /etc/nextcloud && touch /etc/nextcloud/.first-boot-complete"
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nextcloud-first-boot.service

# Reload systemd to pick up new units
systemctl daemon-reload

log_section "12 — Systemd services configured"
