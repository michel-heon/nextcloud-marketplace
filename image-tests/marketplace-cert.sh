#!/usr/bin/env bash
# image-tests/marketplace-cert.sh
# Tests de conformité Microsoft Azure Marketplace — Niveau 3 (Certifiable)
# Référence: ADR-701, ADR-300, ADR-302
# Politique officielle: https://learn.microsoft.com/en-us/legal/marketplace/certification-policies
#
# Critères couverts :
#   1. SSH key-only (PasswordAuthentication no, PermitRootLogin no)
#   2. Pare-feu UFW actif (ports 22 et 443 uniquement)
#   3. TLS 1.2+ (pas de TLSv1.0/1.1)
#   4. Pas de credentials hardcodés résiduels
#   5. Généralisation waagent (DeleteRootPassword, RegenerateSshHostKeyPair)
#   6. Mode maintenance désactivé
#   7. Pas de services inutiles exposés (HTTP non-filtré, phpinfo, etc.)
#   8. Exigences Linux Azure (200.3.3) : architecture 64-bit, hv_netvsc, no-swap,
#      serial console, Azure Linux Agent ≥ 2.2.10
#   9. Propreté image (200.5) : bash history, SSH keys résiduelles, OpenSSL, Defender
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

# ---- 8. Exigences Linux Azure — politique 200.3.3 ----
echo ""
echo "--- 8. Exigences Linux Azure (politique 200.3.3 / 200.4) ---"

# Architecture OS 64-bit
ARCH=$(ssh_run "uname -m" || echo "")
if [[ "${ARCH}" == "x86_64" || "${ARCH}" == "aarch64" ]]; then
    pass "Architecture OS: ${ARCH} (64 bits)"
else
    fail "Architecture OS: ${ARCH} — 64-bit requis pour Azure Marketplace"
fi

# Driver hv_netvsc (réseau Hyper-V) chargé ou compilé dans le kernel
HV_LOADED=$(ssh_run "lsmod 2>/dev/null | grep -c hv_netvsc || echo 0" || echo "0")
if [[ "${HV_LOADED}" != "0" ]]; then
    pass "Driver hv_netvsc chargé (Hyper-V réseau)"
else
    HV_BUILTIN=$(ssh_run "grep -c 'CONFIG_HYPERV_NET=y' /boot/config-\$(uname -r) 2>/dev/null || echo 0" || echo "0")
    if [[ "${HV_BUILTIN}" != "0" ]]; then
        pass "Driver hv_netvsc compilé dans le kernel"
    else
        warn "hv_netvsc non détecté — vérifier la compatibilité Hyper-V (200.3.3)"
    fi
fi

# Pas de partition swap active sur le disque OS
SWAP_ACTIVE=$(ssh_run "swapon --show 2>/dev/null | wc -l || echo 0" || echo "0")
if [[ "${SWAP_ACTIVE}" -eq 0 ]]; then
    pass "Pas de partition swap active (conforme 200.3.3)"
else
    warn "Partition swap active — non recommandé sur l'OS disk Azure (200.3.3)"
fi

# Serial console dans les paramètres GRUB (requis pour débogage Azure — 200.4)
# Note: grep avec '=' pour éviter de matcher GRUB_CMDLINE_LINUX_DEFAULT
GRUB_CMDLINE=$(ssh_run "grep '^GRUB_CMDLINE_LINUX=' /etc/default/grub 2>/dev/null | head -1" || echo "")
if echo "${GRUB_CMDLINE}" | grep -q "console=ttyS0"; then
    pass "GRUB: console=ttyS0 présent (serial console Azure)"
else
    fail "GRUB: console=ttyS0 absent — requis pour le débogage série Azure (politique 200.4)"
fi

# Azure Linux Agent version ≥ 2.2.10
WAAGENT_VER=$(ssh_run "waagent --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1" || echo "")
if [[ -n "${WAAGENT_VER}" ]]; then
    VER_MAJOR=$(echo "${WAAGENT_VER}" | cut -d. -f1)
    VER_MINOR=$(echo "${WAAGENT_VER}" | cut -d. -f2)
    VER_PATCH=$(echo "${WAAGENT_VER}" | cut -d. -f3)
    if (( VER_MAJOR > 2 )) || \
       (( VER_MAJOR == 2 && VER_MINOR > 2 )) || \
       (( VER_MAJOR == 2 && VER_MINOR == 2 && VER_PATCH >= 10 )); then
        pass "Azure Linux Agent: v${WAAGENT_VER} (≥ 2.2.10)"
    else
        fail "Azure Linux Agent: v${WAAGENT_VER} — version minimale 2.2.10 requise"
    fi
else
    fail "Azure Linux Agent (waagent) non installé ou non détectable"
fi

# ---- 9. Propreté de l'image — politique 200.5 ----
echo ""
echo "--- 9. Propreté de l'image (politique 200.5) ---"

# Historique bash vidé lors de la généralisation
BASH_HIST=$(ssh_run "wc -l < ~/.bash_history 2>/dev/null || echo 0" || echo "0")
if [[ "${BASH_HIST}" -eq 0 ]]; then
    pass "Historique bash vide (image dépersonnalisée)"
else
    warn "Historique bash: ${BASH_HIST} ligne(s) — generalize.sh doit vider ~/.bash_history"
fi

# Pas de clés SSH résiduelles d'un buildbot/testeur dans /root
# Note: /home/${TEST_ADMIN_USER}/.ssh/authorized_keys est injecté par Azure à la création — ne pas vérifier
RESIDUAL_KEYS=$(ssh_run \
    "sudo find /root -name 'authorized_keys' 2>/dev/null \
     | xargs -I{} wc -l {} 2>/dev/null | awk '{s+=\$1} END{print s+0}'" || echo "0")
if [[ "${RESIDUAL_KEYS}" -eq 0 ]]; then
    pass "Aucune clé SSH résiduelle dans /root (authorized_keys vides ou absents)"
else
    warn "Clés SSH résiduelles: ${RESIDUAL_KEYS} entrée(s) dans /root — à supprimer dans generalize.sh"
fi

# OpenSSL version ≥ 1.0
OPENSSL_VER=$(ssh_run "openssl version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[a-z]?' | head -1" || echo "")
if [[ -n "${OPENSSL_VER}" ]]; then
    OPENSSL_MAJOR=$(echo "${OPENSSL_VER}" | cut -d. -f1)
    if (( OPENSSL_MAJOR >= 1 )); then
        pass "OpenSSL: v${OPENSSL_VER} (≥ 1.0)"
    else
        fail "OpenSSL: v${OPENSSL_VER} — version 1.0+ requise (200.5)"
    fi
else
    warn "OpenSSL: version non détectable"
fi

# Aucun antivirus Microsoft Defender/MDATP pré-installé (200.4)
DEFENDER=$(ssh_run "dpkg -l 2>/dev/null | grep -Ei 'mdatp|microsoft-defender' | head -3" || echo "")
if [[ -z "${DEFENDER}" ]]; then
    pass "Aucun Microsoft Defender/MDATP pré-installé (conforme 200.4)"
else
    warn "Microsoft Defender/MDATP détecté: ${DEFENDER} — supprimer ou justifier avant publication"
fi

# ImageMagick CVE — politique 200.5.8 (USN-7728-1, USN-7756-1, USN-8021-1, USN-8069-1, USN-8263-1)
# Stratégie de correction : suppression du paquet (patches ESM-only sur Noble 24.04, Ubuntu Pro requis
# pour les appliquer — suppression préférable pour une image Marketplace sans Ubuntu Pro).
# PASS si imagemagick est absent ; FAIL si présent (quelle que soit la version).
IM_PKG=$(ssh_run "dpkg-query -W -f='\${Package}\n' 'imagemagick*' 2>/dev/null \
    | grep -v '^$' | grep -v -E 'common|doc|dbg|dev|perl|ruby|python' | head -1" || echo "")
if [[ -z "${IM_PKG}" ]]; then
    pass "ImageMagick absent — CVE éliminées par suppression du paquet (200.5.8 : USN-7728-1 à USN-8263-1)"
else
    IM_VER=$(ssh_run "dpkg-query -W -f='\${Version}\n' '${IM_PKG}' 2>/dev/null" || echo "inconnu")
    fail "ImageMagick (${IM_PKG}) v${IM_VER} présent — paquet vulnérable doit être supprimé (CVSS 8.5-8.8 : USN-7728-1, USN-7756-1, USN-8021-1, USN-8069-1, USN-8263-1 — correctifs ESM-only sur Noble 24.04) — 200.5.8"
fi

# ---- 10. Rappel AMAT ----
echo ""
echo "--- 10. Azure Marketplace Certification Tool (AMAT) ---"
warn "L'outil AMAT officiel doit être exécuté sur l'image SIG publiée."
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
