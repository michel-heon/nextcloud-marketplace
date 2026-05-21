#!/usr/bin/env bash
# image-tests/service-check.sh
# Vérification complète des services — Niveau 2 (Qualification Fonctionnelle)
# Référence: ADR-701 — Niveau 2 (~10 min)
#
# Usage: bash image-tests/service-check.sh
# Exécute les vérifications via SSH depuis la machine de développement.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_state

echo "========================================"
echo " Service Checks — Niveau 2"
echo " VM    : ${TEST_VM_NAME}"
echo " IP    : ${TEST_VM_IP}"
echo " Image : v${IMAGE_VERSION}"
echo "========================================"
echo ""

# ---- Section 1 : OS ----
echo "--- 1. Système d'exploitation ---"
OS_VERSION=$(ssh_run "lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY | cut -d= -f2 | tr -d '\"'" || echo "unknown")
if echo "${OS_VERSION}" | grep -qi "ubuntu.*24"; then
    pass "OS: ${OS_VERSION}"
else
    fail "OS inattendu: ${OS_VERSION} (attendu: Ubuntu 24.04)"
fi

# ---- Section 2 : Services systemd ----
echo ""
echo "--- 2. Services systemd ---"
SERVICES=(nginx "php8.3-fpm" postgresql redis-server)
for SVC in "${SERVICES[@]}"; do
    STATUS=$(ssh_run "systemctl is-active ${SVC} 2>/dev/null || echo inactive" || echo "unknown")
    if [[ "${STATUS}" == "active" ]]; then
        pass "systemd: ${SVC} actif"
    else
        fail "systemd: ${SVC} ${STATUS}"
    fi
done

# ---- Section 3 : Versions ----
echo ""
echo "--- 3. Versions des composants ---"

# PHP 8.3
PHP_VER=$(ssh_run "php --version 2>/dev/null | head -1" || echo "")
if echo "${PHP_VER}" | grep -q "PHP 8\.3"; then
    pass "PHP: ${PHP_VER%% (*}"
else
    fail "PHP 8.3 introuvable — obtenu: ${PHP_VER:-aucun}"
fi

# PHP-FPM pool
FPM_POOL=$(ssh_run "ls /etc/php/8.3/fpm/pool.d/*.conf 2>/dev/null | head -1" || echo "")
if [[ -n "${FPM_POOL}" ]]; then
    pass "PHP-FPM pool configuré"
else
    warn "Pool PHP-FPM : aucun détecté"
fi

# PostgreSQL 16
PG_VER=$(ssh_run "psql --version 2>/dev/null" || echo "")
if echo "${PG_VER}" | grep -q "16\."; then
    pass "PostgreSQL: ${PG_VER}"
else
    fail "PostgreSQL 16 introuvable — obtenu: ${PG_VER:-aucun}"
fi

# Redis 7
REDIS_VER=$(ssh_run "redis-server --version 2>/dev/null | head -1" || echo "")
if echo "${REDIS_VER}" | grep -q "v=7\."; then
    pass "Redis: ${REDIS_VER}"
else
    warn "Redis version: ${REDIS_VER:-inconnu} (attendu: 7.x)"
fi

# ---- Section 4 : Base de données Nextcloud ----
echo ""
echo "--- 4. Base de données PostgreSQL ---"
DB_EXISTS=$(ssh_run "sudo -u postgres psql -tAc \"SELECT 1 FROM pg_database WHERE datname='nextcloud'\" 2>/dev/null" || echo "")
if [[ "${DB_EXISTS}" == "1" ]]; then
    pass "Base de données 'nextcloud' présente"
else
    fail "Base de données 'nextcloud' introuvable"
fi

NC_USER_EXISTS=$(ssh_run "sudo -u postgres psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='nextcloud'\" 2>/dev/null" || echo "")
if [[ "${NC_USER_EXISTS}" == "1" ]]; then
    pass "Utilisateur PostgreSQL 'nextcloud' présent"
else
    fail "Utilisateur PostgreSQL 'nextcloud' introuvable"
fi

# ---- Section 5 : Nextcloud occ ----
echo ""
echo "--- 5. Nextcloud (occ status) ---"
OCC_STATUS=$(ssh_run "sudo -u www-data php /var/www/nextcloud/occ status --output=json 2>/dev/null" || echo "{}")
OCC_INSTALLED=$(echo "${OCC_STATUS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('installed','false'))" 2>/dev/null || echo "false")
OCC_MAINTENANCE=$(echo "${OCC_STATUS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('maintenance','true'))" 2>/dev/null || echo "true")
OCC_VERSION=$(echo "${OCC_STATUS}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','?'))" 2>/dev/null || echo "?")

if [[ "${OCC_INSTALLED}" == "True" ]]; then
    pass "Nextcloud installé (version: ${OCC_VERSION})"
else
    fail "Nextcloud non installé (occ status: installed=false)"
fi

if [[ "${OCC_MAINTENANCE}" == "False" ]]; then
    pass "Mode maintenance désactivé"
else
    fail "Mode maintenance activé — désactiver avant publication"
fi

# ---- Section 6 : Nginx + TLS ----
echo ""
echo "--- 6. Nginx et TLS ---"
NGINX_TEST=$(ssh_run "sudo nginx -t 2>&1" || echo "FAIL")
if echo "${NGINX_TEST}" | grep -q "syntax is ok"; then
    pass "Nginx: configuration valide"
else
    fail "Nginx: erreur de configuration"
    echo "       ${NGINX_TEST}"
fi

SSL_CERT=$(ssh_run "ls /etc/ssl/nextcloud/ 2>/dev/null || ls /etc/letsencrypt/live/ 2>/dev/null" || echo "")
if [[ -n "${SSL_CERT}" ]]; then
    pass "Certificat TLS présent"
else
    warn "Certificat TLS : répertoire introuvable (vérifier /etc/ssl/nextcloud/ ou /etc/letsencrypt/)"
fi

# ---- Section 7 : Firstboot et marqueur ----
echo ""
echo "--- 7. Marqueur firstboot ---"
if ssh_run "test -f /etc/nextcloud/.first-boot-complete" 2>/dev/null; then
    pass "Marqueur /etc/nextcloud/.first-boot-complete présent"
else
    fail "Marqueur firstboot absent — installation incomplète"
fi

# ---- Section 8 : Cron Nextcloud ----
echo ""
echo "--- 8. Cron Nextcloud ---"
CRON_TIMER=$(ssh_run "systemctl is-active nextcloud-cron.timer 2>/dev/null || echo inactive" || echo "inactive")
CRON_OCC=$(ssh_run "sudo -u www-data crontab -l 2>/dev/null | grep -c nextcloud" || echo "0")
if [[ "${CRON_TIMER}" == "active" ]]; then
    pass "Cron Nextcloud (systemd timer) actif"
elif [[ "${CRON_OCC}" -gt 0 ]]; then
    pass "Cron Nextcloud (crontab) configuré"
else
    warn "Cron Nextcloud non détecté — à vérifier"
fi

# ---- Section 9 : Permissions fichiers ----
echo ""
echo "--- 9. Permissions Nextcloud ---"
NC_OWNER=$(ssh_run "sudo stat -c '%U:%G' /var/www/nextcloud/config/config.php 2>/dev/null" || echo "unknown")
if [[ "${NC_OWNER}" == "www-data:www-data" ]]; then
    pass "config.php appartient à www-data:www-data"
else
    warn "config.php : propriétaire ${NC_OWNER} (attendu: www-data:www-data)"
fi

# ---- Résultats ----
echo ""
echo "========================================"
echo " Résultats Services (Niveau 2)"
echo " PASS: ${PASS} | FAIL: ${FAIL} | WARN: ${WARN}"
echo "========================================"
echo ""
if [[ ${FAIL} -gt 0 ]]; then
    echo "[STOP] Niveau 2 échoué — corriger avant les tests E2E."
    echo "       Cycle de correction : docs/guides/test-image.md#cycle-de-correction"
    exit 1
fi
echo "[OK] Niveau 2 validé — continuer avec : make vm-test-e2e"
