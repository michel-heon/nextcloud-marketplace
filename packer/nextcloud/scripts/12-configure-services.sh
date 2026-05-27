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
After=network-online.target postgresql.service redis-server.service nginx.service cloud-init.target
Wants=network-online.target
# Disable after first successful run
ConditionPathExists=!/etc/nextcloud/.first-boot-complete

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/nc-first-boot.sh
ExecStartPost=/bin/bash -c "mkdir -p /etc/nextcloud && touch /etc/nextcloud/.first-boot-complete"
RemainAfterExit=no

[Install]
WantedBy=cloud-init.target
EOF

systemctl enable nextcloud-first-boot.service

# --- Runtime memory auto-tuning service (runs on every boot) ---
log_info "Installing nextcloud-runtime-autotune service"

cat > /usr/local/bin/nextcloud-runtime-autotune.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/nextcloud/runtime-autotune.log"
mkdir -p /var/log/nextcloud
exec >> "${LOG_FILE}" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] runtime auto-tuning start"

if [[ ! -r /proc/meminfo ]]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] /proc/meminfo unavailable, skip"
	exit 0
fi

MEM_KB="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
if [[ -z "${MEM_KB}" || "${MEM_KB}" -le 0 ]]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] invalid MemTotal, skip"
	exit 0
fi

MEM_MB=$((MEM_KB / 1024))
echo "[$(date '+%Y-%m-%d %H:%M:%S')] detected RAM=${MEM_MB}MB"

clamp() {
	local v="$1" min="$2" max="$3"
	if ((v < min)); then
		echo "${min}"
	elif ((v > max)); then
		echo "${max}"
	else
		echo "${v}"
	fi
}

set_kv() {
	local file="$1" key="$2" value="$3"
	if grep -Eq "^[;#[:space:]]*${key}[[:space:]]*=" "${file}"; then
		sed -E -i "s|^[;#[:space:]]*(${key})[[:space:]]*=.*|\1 = ${value}|" "${file}"
	else
		printf "\n%s = %s\n" "${key}" "${value}" >> "${file}"
	fi
}

# PHP-FPM
PHP_WWW_CONF=""
for candidate in /etc/php/*/fpm/pool.d/www.conf; do
	[[ -f "${candidate}" ]] && PHP_WWW_CONF="${candidate}" && break
done

if [[ -n "${PHP_WWW_CONF}" ]]; then
	php_budget_mb=$((MEM_MB * 35 / 100))
	php_budget_mb="$(clamp "${php_budget_mb}" 512 8192)"
	pm_max_children=$((php_budget_mb / 128))
	pm_max_children="$(clamp "${pm_max_children}" 8 200)"
	pm_start_servers="$(clamp "$((pm_max_children / 4))" 2 32)"
	pm_min_spare_servers="$(clamp "$((pm_max_children / 6))" 2 32)"
	pm_max_spare_servers="$(clamp "$((pm_max_children / 2))" 4 96)"
	if ((pm_max_spare_servers >= pm_max_children)); then
		pm_max_spare_servers=$((pm_max_children - 1))
	fi

	if ((MEM_MB <= 4096)); then
		php_memory_limit="512M"
	elif ((MEM_MB <= 8192)); then
		php_memory_limit="768M"
	else
		php_memory_limit="1024M"
	fi

	set_kv "${PHP_WWW_CONF}" "pm.max_children" "${pm_max_children}"
	set_kv "${PHP_WWW_CONF}" "pm.start_servers" "${pm_start_servers}"
	set_kv "${PHP_WWW_CONF}" "pm.min_spare_servers" "${pm_min_spare_servers}"
	set_kv "${PHP_WWW_CONF}" "pm.max_spare_servers" "${pm_max_spare_servers}"
	set_kv "${PHP_WWW_CONF}" "php_admin_value[memory_limit]" "${php_memory_limit}"
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] tuned PHP-FPM max_children=${pm_max_children} memory_limit=${php_memory_limit}"
fi

# Redis
REDIS_CONF="/etc/redis/redis.conf"
if [[ -f "${REDIS_CONF}" ]]; then
	redis_max_mb=$((MEM_MB * 10 / 100))
	redis_max_mb="$(clamp "${redis_max_mb}" 128 2048)"
	set_kv "${REDIS_CONF}" "maxmemory" "${redis_max_mb}mb"
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] tuned Redis maxmemory=${redis_max_mb}mb"
fi

# PostgreSQL
PG_CONF=""
for candidate in /etc/postgresql/*/main/postgresql.conf; do
	[[ -f "${candidate}" ]] && PG_CONF="${candidate}" && break
done

if [[ -n "${PG_CONF}" ]]; then
	pg_shared_mb="$(clamp "$((MEM_MB * 25 / 100))" 128 8192)"
	pg_cache_mb="$(clamp "$((MEM_MB * 50 / 100))" 256 16384)"
	pg_maint_mb="$(clamp "$((MEM_MB * 5 / 100))" 64 2048)"
	pg_work_mb="$(clamp "$((MEM_MB / 64))" 4 64)"

	set_kv "${PG_CONF}" "shared_buffers" "'${pg_shared_mb}MB'"
	set_kv "${PG_CONF}" "effective_cache_size" "'${pg_cache_mb}MB'"
	set_kv "${PG_CONF}" "maintenance_work_mem" "'${pg_maint_mb}MB'"
	set_kv "${PG_CONF}" "work_mem" "'${pg_work_mb}MB'"
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] tuned PostgreSQL shared_buffers=${pg_shared_mb}MB work_mem=${pg_work_mb}MB"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] runtime auto-tuning complete"
EOF

chmod 750 /usr/local/bin/nextcloud-runtime-autotune.sh
chown root:root /usr/local/bin/nextcloud-runtime-autotune.sh

cat > /etc/systemd/system/nextcloud-runtime-autotune.service <<'EOF'
[Unit]
Description=Nextcloud runtime memory auto-tuning
After=local-fs.target
Before=postgresql.service redis-server.service nginx.service php8.3-fpm.service nextcloud-first-boot.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/nextcloud-runtime-autotune.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nextcloud-runtime-autotune.service

# Reload systemd to pick up new units
systemctl daemon-reload

log_section "12 — Systemd services configured"
