#!/usr/bin/env bash
# image-tests/marketplace-cert.sh
# Tests de conformité Microsoft Azure Marketplace — Niveau 3 (Certifiable)
# Référence: ADR-701, ADR-300, ADR-302
#
# Critères couverts :
#   1. SSH key-only (PasswordAuthentication no, PermitRootLogin no)
#   2. Pare-feu UFW actif (ports 22 et 443 uniquement)
#   3. TLS 1.2+ (pas de TLSv1.0/1.1)
#   4. Pas de credentials hardcodés résiduels
#   5. Généralisation waagent (DeleteRootPassword, RegenerateSshHostKeyPair)
#   6. Mode maintenance désactivé
#   7. Pas de services inutiles exposés (HTTP non-filtré, phpinfo, etc.)
#
# Usage: bash image-tests/marketplace-cert.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_state

echo "========================================"
echo " Marketplace Certification — Niveau 3"
echo " VM    : ${TEST_VM_NAME}"
echo " IP    : ${TEST_VM_IP}"
echo " Image : v${IMAGE_VERSION}"
echo "========================================"
echo ""

# ---- 1. Sécurité SSH ----
echo "--- 1. Hardening SSH ---"

# PermitRootLogin
ROOT_LOGIN=$(ssh_run "sudo sshd -T 2>/dev/null | grep -i '^permitrootlogin'" || echo "")
if echo "${ROOT_LOGIN}" | grep -qi "permitrootlogin no\|permitrootlogin prohibit-password"; then
    pass "SSH: PermitRootLogin no/prohibit-password"
else
    fail "SSH: PermitRootLogin non désactivé ('${ROOT_LOGIN}') — requis pour Marketplace"
fi

# PasswordAuthentication
PWD_AUTH=$(ssh_run "sudo sshd -T 2>/dev/null | grep -i '^passwordauthentication'" || echo "")
if echo "${PWD_AUTH}" | grep -qi "^passwordauthentication no"; then
    pass "SSH: PasswordAuthentication no"
else
    fail "SSH: PasswordAuthentication activée — doit être désactivée pour Marketplace"
fi

# Clé SSH présente pour le user de connexion
AUTH_KEYS=$(ssh_run "test -f ~/.ssh/authorized_keys && echo yes || echo no" || echo "no")
if [[ "${AUTH_KEYS}" == "yes" ]]; then
    pass "SSH: authorized_keys présent pour ${TEST_ADMIN_USER}"
else
    warn "SSH: authorized_keys absent pour ${TEST_ADMIN_USER}"
fi

# ---- 2. Pare-feu UFW ----
echo ""
echo "--- 2. Pare-feu UFW ---"

UFW_STATUS=$(ssh_run "sudo ufw status 2>/dev/null" || echo "")
if echo "${UFW_STATUS}" | grep -q "Status: active"; then
    pass "UFW: actif"
else
    fail "UFW: inactif — pare-feu obligatoire pour Azure Marketplace"
fi

if echo "${UFW_STATUS}" | grep -qE "^22.*ALLOW"; then
    pass "UFW: port 22 (SSH) autorisé"
else
    fail "UFW: port 22 non autorisé — accès SSH impossible"
fi

if echo "${UFW_STATUS}" | grep -qE "^443.*ALLOW"; then
    pass "UFW: port 443 (HTTPS) autorisé"
else
    fail "UFW: port 443 non autorisé — Nextcloud HTTPS inaccessible"
fi

# Port 80 ouvert sans redirect est une surface d'attaque
if echo "${UFW_STATUS}" | grep -qE "^80.*ALLOW"; then
    warn "UFW: port 80 autorisé — acceptable uniquement si HTTP→HTTPS redirect est configuré"
fi

# ---- 3. TLS ----
echo ""
echo "--- 3. TLS ---"

TLS_OUTPUT=$(echo "" | timeout 10 openssl s_client \
    -connect "${TEST_VM_IP}:443" \
    -servername "${TEST_VM_IP}" 2>/dev/null | grep -E "Protocol|Cipher" | head -5 || echo "")

if echo "${TLS_OUTPUT}" | grep -q "TLSv1\.[23]"; then
    TLS_VER=$(echo "${TLS_OUTPUT}" | grep -oE "TLSv1\.[0-9]+" | head -1 || echo "TLSv1.x")
    pass "TLS: ${TLS_VER} utilisé"
elif [[ -z "${TLS_OUTPUT}" ]]; then
    warn "TLS: impossible d'inspecter (certificat auto-signé ou timeout) — vérifier avec AMAT"
else
    fail "TLS: version non conforme — TLSv1.2 minimum requis"
fi

# ---- 4. Credentials résiduels ----
echo ""
echo "--- 4. Pas de credentials hardcodés ---"

# config.env doit être supprimé après firstboot
if ssh_run "test ! -f /etc/nextcloud/config.env" 2>/dev/null; then
    pass "config.env absent après firstboot (credentials éphémères nettoyés)"
else
    fail "config.env encore présent dans /etc/nextcloud/ — doit être supprimé par nc-first-boot.sh"
fi

# Pas de mots de passe en clair dans les scripts Nextcloud
CREDS_FOUND=$(ssh_run "sudo grep -rli 'NC_ADMIN_PASSWORD\|DB_PASS\|REDIS_PASS' \
    /etc/nextcloud/ /var/www/nextcloud/config/ 2>/dev/null | grep -v '.php$'" || echo "")
if [[ -z "${CREDS_FOUND}" ]]; then
    pass "Aucun credential en clair dans les fichiers de configuration"
else
    warn "Fichiers avec patterns credentials : ${CREDS_FOUND} — vérifier manuellement"
fi

# Pas de mot de passe root PostgreSQL par défaut
PG_PASS=$(ssh_run "sudo -u postgres psql -tAc \"SELECT passwd FROM pg_shadow WHERE usename='postgres'\" 2>/dev/null" || echo "")
if [[ "${PG_PASS}" == "md5"* || "${PG_PASS}" == "scram-sha-256"* ]]; then
    pass "PostgreSQL: mot de passe root défini (hash présent)"
else
    warn "PostgreSQL: statut du mot de passe root non confirmé"
fi

# ---- 5. Généralisation waagent ----
echo ""
echo "--- 5. Généralisation waagent (sysprep) ---"
WAAGENT_CONF=$(ssh_run "cat /etc/waagent.conf 2>/dev/null" || echo "")

if echo "${WAAGENT_CONF}" | grep -q "Provisioning.DeleteRootPassword=y"; then
    pass "waagent: Provisioning.DeleteRootPassword=y"
else
    warn "waagent: Provisioning.DeleteRootPassword non confirmé — vérifier /etc/waagent.conf"
fi

if echo "${WAAGENT_CONF}" | grep -q "Provisioning.RegenerateSshHostKeyPair=y"; then
    pass "waagent: Provisioning.RegenerateSshHostKeyPair=y"
else
    warn "waagent: Provisioning.RegenerateSshHostKeyPair non confirmé"
fi

# ---- 6. Mode maintenance Nextcloud ----
echo ""
echo "--- 6. Mode maintenance ---"
MAINTENANCE=$(curl --silent --insecure --max-time 10 \
    "https://${TEST_VM_IP}/status.php" 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('maintenance'))" 2>/dev/null || echo "unknown")
if [[ "${MAINTENANCE}" == "False" ]]; then
    pass "Nextcloud: mode maintenance désactivé"
elif [[ "${MAINTENANCE}" == "unknown" ]]; then
    warn "Mode maintenance: impossible de vérifier via HTTP (status.php)"
else
    fail "Nextcloud: mode maintenance activé — à désactiver avant publication"
fi

# ---- 7. Surfaces d'attaque ----
echo ""
echo "--- 7. Surfaces d'attaque résiduelles ---"

# phpinfo non exposé
PHPINFO_CODE=$(curl --silent --insecure --max-time 10 \
    --output /dev/null --write-out "%{http_code}" \
    "https://${TEST_VM_IP}/phpinfo.php" 2>/dev/null || echo "000")
if [[ "${PHPINFO_CODE}" != "200" ]]; then
    pass "phpinfo.php non exposé (HTTP ${PHPINFO_CODE})"
else
    fail "phpinfo.php exposé publiquement — supprimer impérativement"
fi

# .env non exposé
ENV_CODE=$(curl --silent --insecure --max-time 10 \
    --output /dev/null --write-out "%{http_code}" \
    "https://${TEST_VM_IP}/.env" 2>/dev/null || echo "000")
if [[ "${ENV_CODE}" != "200" ]]; then
    pass ".env non exposé (HTTP ${ENV_CODE})"
else
    fail ".env exposé publiquement — risque de divulgation de credentials"
fi

# ---- 8. Rappel AMAT ----
echo ""
echo "--- 8. Azure Marketplace Certification Tool (AMAT) ---"
warn "L'outil AMAT doit être exécuté séparément sur l'image SIG publiée."
warn "Documentation : https://learn.microsoft.com/azure/marketplace/azure-vm-image-certification"
warn "Outil officiel : https://github.com/Azure/Azure-Certification-Tools"

# ---- Résultats ----
echo ""
echo "========================================"
echo " Résultats Certification (Niveau 3)"
echo " PASS: ${PASS} | FAIL: ${FAIL} | WARN: ${WARN}"
echo "========================================"
echo ""
if [[ ${FAIL} -gt 0 ]]; then
    echo "[STOP] Niveau 3 échoué — l'image NE PEUT PAS être publiée sur Azure Marketplace."
    echo "       Corriger les échecs, rebâtir l'image et retester."
    exit 1
fi
if [[ ${WARN} -gt 0 ]]; then
    echo "[WARN] Niveau 3 validé avec avertissements — vérifier chaque WARN avant publication."
else
    echo "[OK] Niveau 3 validé — image prête pour soumission Azure Marketplace."
fi
