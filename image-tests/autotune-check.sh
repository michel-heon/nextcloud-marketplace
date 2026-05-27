#!/usr/bin/env bash
# image-tests/autotune-check.sh
# Validation post-boot du runtime auto-tuning mémoire (PHP-FPM, Redis, PostgreSQL)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_state

echo "========================================"
echo " Runtime Auto-tuning Check — Post-boot"
echo " VM    : ${TEST_VM_NAME}"
echo " IP    : ${TEST_VM_IP}"
echo " Image : v${IMAGE_VERSION}"
echo "========================================"
echo ""

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

echo "--- 1. Service systemd auto-tuning ---"
AUTO_ENABLED=$(ssh_run "systemctl is-enabled nextcloud-runtime-autotune.service 2>/dev/null || echo disabled" || echo "disabled")
AUTO_RESULT=$(ssh_run "systemctl show -p Result --value nextcloud-runtime-autotune.service 2>/dev/null || echo unknown" || echo "unknown")

if [[ "${AUTO_ENABLED}" == "enabled" ]]; then
    pass "Service nextcloud-runtime-autotune activé au boot"
else
    fail "Service nextcloud-runtime-autotune non activé (état: ${AUTO_ENABLED})"
fi

if [[ "${AUTO_RESULT}" == "success" ]]; then
    pass "Dernière exécution systemd réussie"
else
    fail "Dernière exécution systemd non réussie (Result=${AUTO_RESULT})"
fi

LOG_LAST=$(ssh_run "sudo tail -n 2 /var/log/nextcloud/runtime-autotune.log 2>/dev/null | tr '\n' '|'" || echo "")
if echo "${LOG_LAST}" | grep -q "runtime auto-tuning complete"; then
    pass "Log auto-tuning présent et complet"
else
    warn "Log auto-tuning absent/incomplet (/var/log/nextcloud/runtime-autotune.log)"
fi

echo ""
echo "--- 2. Calcul attendu selon RAM détectée ---"
MEM_MB=$(ssh_run "awk '/^MemTotal:/{print int(\$2/1024)}' /proc/meminfo" || echo "0")
if [[ -z "${MEM_MB}" || "${MEM_MB}" == "0" ]]; then
    fail "Impossible de lire la RAM de la VM"
    print_summary
    exit 1
fi
pass "RAM détectée: ${MEM_MB} MB"

PHP_BUDGET_MB=$((MEM_MB * 35 / 100))
PHP_BUDGET_MB=$(clamp "${PHP_BUDGET_MB}" 512 8192)
EXP_PM_MAX=$((PHP_BUDGET_MB / 128))
EXP_PM_MAX=$(clamp "${EXP_PM_MAX}" 8 200)

if ((MEM_MB <= 4096)); then
    EXP_PHP_LIMIT="512M"
elif ((MEM_MB <= 8192)); then
    EXP_PHP_LIMIT="768M"
else
    EXP_PHP_LIMIT="1024M"
fi

EXP_REDIS_MB=$((MEM_MB * 10 / 100))
EXP_REDIS_MB=$(clamp "${EXP_REDIS_MB}" 128 2048)
EXP_REDIS="${EXP_REDIS_MB}mb"

EXP_PG_SHARED_MB=$((MEM_MB * 25 / 100))
EXP_PG_SHARED_MB=$(clamp "${EXP_PG_SHARED_MB}" 128 8192)
EXP_PG_SHARED="'${EXP_PG_SHARED_MB}MB'"

echo ""
echo "--- 3. Vérification PHP-FPM ---"
PHP_WWW_CONF=$(ssh_run "ls /etc/php/*/fpm/pool.d/www.conf 2>/dev/null | head -1" || echo "")
if [[ -z "${PHP_WWW_CONF}" ]]; then
    fail "Fichier PHP-FPM www.conf introuvable"
else
    ACT_PM_MAX=$(ssh_run "awk -F= '/^[[:space:]]*pm.max_children/{v=\$2} END{if(v!=\"\"){gsub(/[[:space:]]/,\"\",v); print v}}' ${PHP_WWW_CONF}" || echo "")
    ACT_PHP_LIMIT=$(ssh_run "awk -F= '/php_admin_value\\[memory_limit\\]/{v=\$2} END{if(v!=\"\"){gsub(/[[:space:]]/,\"\",v); print v}}' ${PHP_WWW_CONF}" || echo "")

    if [[ "${ACT_PM_MAX}" == "${EXP_PM_MAX}" ]]; then
        pass "pm.max_children=${ACT_PM_MAX} (attendu ${EXP_PM_MAX})"
    else
        fail "pm.max_children=${ACT_PM_MAX:-vide} (attendu ${EXP_PM_MAX})"
    fi

    if [[ "${ACT_PHP_LIMIT}" == "${EXP_PHP_LIMIT}" ]]; then
        pass "php memory_limit=${ACT_PHP_LIMIT} (attendu ${EXP_PHP_LIMIT})"
    else
        fail "php memory_limit=${ACT_PHP_LIMIT:-vide} (attendu ${EXP_PHP_LIMIT})"
    fi
fi

echo ""
echo "--- 4. Vérification Redis ---"
ACT_REDIS=$(ssh_run "sudo awk '/^[[:space:]]*maxmemory[[:space:]]/{line=\$0} END {if (line != \"\") {gsub(/^[[:space:]]*maxmemory[[:space:]]*=?[[:space:]]*/, \"\", line); print line}}' /etc/redis/redis.conf 2>/dev/null" || echo "")
if [[ "${ACT_REDIS}" == "${EXP_REDIS}" ]]; then
    pass "redis maxmemory=${ACT_REDIS} (attendu ${EXP_REDIS})"
else
    fail "redis maxmemory=${ACT_REDIS:-vide} (attendu ${EXP_REDIS})"
fi

echo ""
echo "--- 5. Vérification PostgreSQL ---"
PG_CONF=$(ssh_run "ls /etc/postgresql/*/main/postgresql.conf 2>/dev/null | head -1" || echo "")
if [[ -z "${PG_CONF}" ]]; then
    fail "Fichier postgresql.conf introuvable"
else
    ACT_PG_SHARED=$(ssh_run "awk -F= '/^[#[:space:]]*shared_buffers[[:space:]]*=/{v=\$2} END{if(v!=\"\"){gsub(/^[[:space:]]+|[[:space:]]+$/,\"\",v); print v}}' ${PG_CONF}" || echo "")
    if [[ "${ACT_PG_SHARED}" == "${EXP_PG_SHARED}" ]]; then
        pass "postgresql shared_buffers=${ACT_PG_SHARED} (attendu ${EXP_PG_SHARED})"
    else
        fail "postgresql shared_buffers=${ACT_PG_SHARED:-vide} (attendu ${EXP_PG_SHARED})"
    fi
fi

print_summary
