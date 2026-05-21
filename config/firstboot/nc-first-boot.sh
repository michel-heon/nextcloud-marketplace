#!/usr/bin/env bash
# nc-first-boot.sh — Nextcloud first-boot setup
# Runs once at first VM launch via nextcloud-first-boot.service
# Reads configuration from /etc/nextcloud/config.env (populated by cloud-init)

set -euo pipefail

LOG_FILE="/var/log/nextcloud/first-boot.log"
mkdir -p /var/log/nextcloud
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nextcloud first-boot setup starting"
echo "============================================================"

CONFIG_ENV="/etc/nextcloud/config.env"

if [[ ! -f "${CONFIG_ENV}" ]]; then
  echo "ERROR: ${CONFIG_ENV} not found. Cloud-init must create this file." >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${CONFIG_ENV}"

# Required variables (cloud-init must supply these)
: "${NC_ADMIN_USER:?Must be set in ${CONFIG_ENV}}"
: "${NC_ADMIN_PASSWORD:?Must be set in ${CONFIG_ENV}}"
: "${NC_DB_PASSWORD:?Must be set in ${CONFIG_ENV}}"
: "${REDIS_PASSWORD:?Must be set in ${CONFIG_ENV}}"
: "${NC_TRUSTED_DOMAIN:?Must be set in ${CONFIG_ENV}}"

NC_WEBROOT="/var/www/nextcloud"
NC_DATA_DIR="/var/nextcloud-data"
OCC="sudo -u www-data php ${NC_WEBROOT}/occ"

# --- Update PostgreSQL password ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting PostgreSQL nextcloud user password"
sudo -u postgres psql -c "ALTER ROLE nextcloud WITH PASSWORD '${NC_DB_PASSWORD}';"

# --- Update Redis password ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating Redis requirepass"
sed -i "s/^requirepass .*/requirepass ${REDIS_PASSWORD}/" /etc/redis/redis.conf
systemctl restart redis-server
# Wait for Redis
sleep 2
redis-cli -a "${REDIS_PASSWORD}" ping | grep -q PONG

# --- Nextcloud installation ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running occ maintenance:install"
${OCC} maintenance:install \
  --database "pgsql" \
  --database-host "127.0.0.1" \
  --database-port "5432" \
  --database-name "nextcloud" \
  --database-user "nextcloud" \
  --database-pass "${NC_DB_PASSWORD}" \
  --admin-user "${NC_ADMIN_USER}" \
  --admin-pass "${NC_ADMIN_PASSWORD}" \
  --data-dir "${NC_DATA_DIR}"

# --- Trusted domains ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring trusted domains"
${OCC} config:system:set trusted_domains 0 --value="localhost"
${OCC} config:system:set trusted_domains 1 --value="${NC_TRUSTED_DOMAIN}"

# --- Redis session caching ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring Redis caching"
${OCC} config:system:set memcache.local     --value='\OC\Memcache\APCu'
${OCC} config:system:set memcache.locking   --value='\OC\Memcache\Redis'
${OCC} config:system:set memcache.distributed --value='\OC\Memcache\Redis'
${OCC} config:system:set redis host         --value='127.0.0.1'
${OCC} config:system:set redis port         --value=6379 --type=integer
${OCC} config:system:set redis password     --value="${REDIS_PASSWORD}"
${OCC} config:system:set redis dbindex      --value=0 --type=integer

# --- Performance tuning ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Applying performance settings"
${OCC} config:system:set default_phone_region  --value="CA"
${OCC} config:system:set log_type             --value="file"
${OCC} config:system:set logfile              --value="/var/log/nextcloud/nextcloud.log"
${OCC} config:system:set loglevel             --value=2 --type=integer
${OCC} config:system:set maintenance_window_start --value=1 --type=integer

# Enable background job via cron (instead of AJAX)
${OCC} background:cron

# --- Start services ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting services"
systemctl start nextcloud-cron.timer

echo "============================================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nextcloud first-boot setup COMPLETE"
echo "============================================================"
