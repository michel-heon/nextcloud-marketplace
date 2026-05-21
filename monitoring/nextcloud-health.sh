#!/usr/bin/env bash
# monitoring/nextcloud-health.sh
# Checks Nextcloud application health and critical service status.
# Exit codes: 0 = healthy, 1 = degraded, 2 = critical
set -euo pipefail

NEXTCLOUD_URL="${NEXTCLOUD_URL:-https://localhost}"
TIMEOUT=10
OVERALL_STATUS=0

# --------------------------------------------------------------------------
check_http() {
    local url="${1}"
    local description="${2}"
    local http_code
    http_code=$(curl --silent --insecure --max-time "${TIMEOUT}" \
                    --output /dev/null --write-out "%{http_code}" "${url}" || echo "000")

    if [[ "${http_code}" == "200" ]]; then
        echo "[OK]   HTTP ${description}: ${http_code}"
    else
        echo "[FAIL] HTTP ${description}: ${http_code} (expected 200)"
        OVERALL_STATUS=2
    fi
}

check_service() {
    local service="${1}"
    if systemctl is-active --quiet "${service}"; then
        echo "[OK]   Service ${service}: active"
    else
        echo "[FAIL] Service ${service}: NOT active"
        OVERALL_STATUS=2
    fi
}

check_nextcloud_status() {
    local status_json
    status_json=$(curl --silent --insecure --max-time "${TIMEOUT}" \
                       "${NEXTCLOUD_URL}/status.php" 2>/dev/null || echo "{}")

    local installed
    installed=$(echo "${status_json}" | grep -oP '"installed"\s*:\s*\K(true|false)' || echo "unknown")
    local maintenance
    maintenance=$(echo "${status_json}" | grep -oP '"maintenance"\s*:\s*\K(true|false)' || echo "unknown")
    local version
    version=$(echo "${status_json}" | grep -oP '"versionstring"\s*:\s*"\K[^"]+' || echo "unknown")

    echo "[INFO] Nextcloud installed=${installed} maintenance=${maintenance} version=${version}"

    if [[ "${installed}" != "true" ]]; then
        echo "[FAIL] Nextcloud is not installed or status.php is unreachable"
        OVERALL_STATUS=2
    fi
    if [[ "${maintenance}" == "true" ]]; then
        echo "[WARN] Nextcloud is in maintenance mode"
        if [[ "${OVERALL_STATUS}" -lt 1 ]]; then OVERALL_STATUS=1; fi
    fi
}

# --------------------------------------------------------------------------
echo "=== Nextcloud Health Check ==="
echo "URL: ${NEXTCLOUD_URL}"
echo ""

echo "--- Services ---"
check_service "nginx"
# Dynamically detect installed PHP-FPM version
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3")
check_service "php${PHP_VERSION}-fpm"
check_service "postgresql@16-main"
check_service "redis-server"
check_service "nextcloud-cron.timer"

echo ""
echo "--- HTTP ---"
check_http "${NEXTCLOUD_URL}/status.php" "status.php"
check_nextcloud_status

echo ""
echo "--- Redis ping ---"
if redis-cli ping 2>/dev/null | grep -q PONG; then
    echo "[OK]   Redis: PONG"
else
    echo "[FAIL] Redis: no PONG"
    OVERALL_STATUS=2
fi

echo ""
if [[ "${OVERALL_STATUS}" -eq 0 ]]; then
    echo "=== RESULT: HEALTHY ==="
elif [[ "${OVERALL_STATUS}" -eq 1 ]]; then
    echo "=== RESULT: DEGRADED ==="
else
    echo "=== RESULT: CRITICAL ==="
fi

exit "${OVERALL_STATUS}"
