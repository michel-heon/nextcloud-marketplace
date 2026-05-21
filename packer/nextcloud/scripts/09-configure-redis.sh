#!/usr/bin/env bash
# 09-configure-redis.sh — Deploy Redis configuration for Nextcloud session caching

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.sh"

log_section "09 — Configure Redis"

log_info "Deploying Redis configuration"
install -m 640 /tmp/config/redis/redis-nextcloud.conf /etc/redis/redis.conf
chown redis:redis /etc/redis/redis.conf

log_info "Restarting Redis"
systemctl restart redis-server

log_info "Verifying Redis is listening on 127.0.0.1"
REDIS_PASS=$(awk '/^requirepass/{print $2}' /etc/redis/redis.conf)
redis-cli --no-auth-warning -a "${REDIS_PASS}" ping | grep -q PONG && log_info "Redis is healthy"

log_section "09 — Redis configuration complete"
