#!/usr/bin/env bash
# tests/check-services.sh — Vérification des services et composants Nextcloud
# Usage direct (à l'intérieur de la VM) :
#   sudo bash tests/check-services.sh
# Usage via Makefile (SSH depuis le poste de développement) :
#   make vm-check VM_SSH=azureuser@<ip>

set -euo pipefail

PASS=0
FAIL=0

pass() { echo "[PASS] $*"; ((PASS++)); }
fail() { echo "[FAIL] $*"; ((FAIL++)); }

echo "=== Nextcloud Image — Vérification des services ==="
echo ""

# ------------------------------------------------------------
# OS
# ------------------------------------------------------------
echo "--- OS ---"
distro=$(lsb_release -d 2>/dev/null | awk -F'\t' '{print $2}' || echo "")
if echo "$distro" | grep -q "Ubuntu 24.04"; then
    pass "OS : $distro"
else
    fail "OS inattendu : ${distro:-inconnu}"
fi

# ------------------------------------------------------------
# Services systemd
# ------------------------------------------------------------
echo ""
echo "--- Services systemd ---"
for svc in nginx php8.3-fpm postgresql redis-server; do
    state=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
    if [[ "$state" == "active" ]]; then
        pass "Service ${svc} : actif"
    else
        fail "Service ${svc} : ${state}"
    fi
done

# ------------------------------------------------------------
# PHP
# ------------------------------------------------------------
echo ""
echo "--- PHP ---"
php_cli=$(php --version 2>/dev/null | head -1 || echo "")
if echo "$php_cli" | grep -qE "^PHP 8\.3\."; then
    pass "PHP CLI : $php_cli"
else
    fail "PHP CLI inattendu : ${php_cli:-non trouvé}"
fi

php_fpm=$(php-fpm8.3 --version 2>/dev/null | head -1 || echo "")
if echo "$php_fpm" | grep -qE "^PHP 8\.3\."; then
    pass "PHP-FPM : $php_fpm"
else
    fail "PHP-FPM inattendu : ${php_fpm:-non trouvé}"
fi

# ------------------------------------------------------------
# PostgreSQL
# ------------------------------------------------------------
echo ""
echo "--- PostgreSQL ---"
pg_ver=$(psql --version 2>/dev/null || echo "")
if echo "$pg_ver" | grep -qE "PostgreSQL\) 16\."; then
    pass "PostgreSQL : $pg_ver"
else
    fail "PostgreSQL inattendu : ${pg_ver:-non trouvé}"
fi

db_exists=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='nextcloud'" 2>/dev/null || echo "")
if [[ "$db_exists" == "1" ]]; then
    pass "Base de données 'nextcloud' présente"
else
    fail "Base de données 'nextcloud' absente"
fi

# ------------------------------------------------------------
# Redis
# ------------------------------------------------------------
echo ""
echo "--- Redis ---"
ping_result=$(redis-cli ping 2>/dev/null || echo "")
if [[ "$ping_result" == "PONG" ]]; then
    pass "Redis : PONG"
else
    fail "Redis ping : ${ping_result:-aucune réponse}"
fi

# ------------------------------------------------------------
# Nextcloud
# ------------------------------------------------------------
echo ""
echo "--- Nextcloud ---"
nc_version_file="/var/www/nextcloud/version.php"
if [[ -f "$nc_version_file" ]]; then
    pass "version.php présent"
    nc_ver=$(grep OC_VersionString "$nc_version_file" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1 || echo "")
    if [[ -n "$nc_ver" ]]; then
        pass "Nextcloud version : $nc_ver"
    else
        fail "Impossible de lire OC_VersionString dans version.php"
    fi
else
    fail "version.php absent (${nc_version_file})"
fi

owner=$(stat -c "%U:%G" /var/www/nextcloud 2>/dev/null || echo "")
if [[ "$owner" == "www-data:www-data" ]]; then
    pass "Propriétaire /var/www/nextcloud : $owner"
else
    fail "Propriétaire /var/www/nextcloud incorrect : ${owner:-inconnu}"
fi

# ------------------------------------------------------------
# Sécurité
# ------------------------------------------------------------
echo ""
echo "--- Sécurité ---"
ufw_status=$(sudo ufw status 2>/dev/null | head -1 || echo "")
if echo "$ufw_status" | grep -qi "active"; then
    pass "UFW : actif"
else
    fail "UFW : ${ufw_status:-statut inconnu}"
fi

f2b_jails=$(sudo fail2ban-client status 2>/dev/null | grep "Number of jail" | grep -oE "[0-9]+" || echo "0")
if [[ "$f2b_jails" -ge 1 ]]; then
    pass "fail2ban : ${f2b_jails} jail(s) actif(s)"
else
    fail "fail2ban : aucun jail actif"
fi

# ------------------------------------------------------------
# Résumé
# ------------------------------------------------------------
echo ""
echo "=== Résultats : ${PASS} passé(s), ${FAIL} échoué(s) ==="

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
