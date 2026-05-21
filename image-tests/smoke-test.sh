#!/usr/bin/env bash
# image-tests/smoke-test.sh
# Tests de smoke — Niveau 1 (VM alive, SSH, firstboot, HTTPS)
# Référence: ADR-701 — Niveau 1 Smoke (<2 min)
#
# Usage: bash image-tests/smoke-test.sh
# Prérequis: .image-test-state doit exister (make vm-test-create)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_state

echo "========================================"
echo " Smoke Tests — Niveau 1"
echo " VM    : ${TEST_VM_NAME}"
echo " IP    : ${TEST_VM_IP}"
echo " Image : v${IMAGE_VERSION}"
echo "========================================"
echo ""

# ---- Critère 1 : VM state ----
echo "--- 1. État de la VM ---"
VM_STATE=$(az vm show \
    --resource-group "${TEST_RG}" \
    --name "${TEST_VM_NAME}" \
    --show-details \
    --query "powerState" -o tsv 2>/dev/null || echo "unknown")
if [[ "${VM_STATE}" == "VM running" ]]; then
    pass "VM state: ${VM_STATE}"
else
    fail "VM state: '${VM_STATE}' (attendu: 'VM running')"
fi

# ---- Critère 2 : SSH accessible ----
echo ""
echo "--- 2. Accessibilité SSH ---"
if ssh_run exit 2>/dev/null; then
    pass "SSH accessible (${TEST_ADMIN_USER}@${TEST_VM_IP})"
else
    fail "SSH inaccessible — timeout ou connexion refusée"
    echo ""
    echo "  Résultats : PASS=${PASS} FAIL=${FAIL} WARN=${WARN}"
    echo "  [STOP] SSH inaccessible — impossible de continuer."
    exit 1
fi

# ---- Critère 3 : Firstboot terminé ----
echo ""
echo "--- 3. Service nextcloud-first-boot ---"
FB_STATUS=$(ssh_run "systemctl is-active nextcloud-first-boot.service 2>/dev/null || echo unknown" || echo "ssh-error")
FB_MARKER=$(ssh_run "test -f /etc/nextcloud/.first-boot-complete && echo yes || echo no" || echo "no")

if [[ "${FB_MARKER}" == "yes" ]]; then
    pass "Firstboot terminé (marqueur /etc/nextcloud/.first-boot-complete présent)"
elif [[ "${FB_STATUS}" == "active" || "${FB_STATUS}" == "activating" ]]; then
    warn "Firstboot encore en cours (état: ${FB_STATUS}) — réessayer dans quelques minutes"
else
    fail "Firstboot incomplet (état: ${FB_STATUS}, marqueur: ${FB_MARKER})"
    echo "      Diagnostic :"
    echo "        make vm-test-ssh"
    echo "        sudo journalctl -u nextcloud-first-boot.service --no-pager -n 50"
fi

# ---- Critère 4 : Services systemd critiques ----
echo ""
echo "--- 4. Services systemd ---"
for SVC in nginx "php8.3-fpm" postgresql redis-server; do
    STATUS=$(ssh_run "systemctl is-active ${SVC} 2>/dev/null || echo inactive" || echo "unknown")
    if [[ "${STATUS}" == "active" ]]; then
        pass "Service ${SVC}: actif"
    else
        fail "Service ${SVC}: ${STATUS}"
    fi
done

# ---- Critère 5 : HTTPS répond ----
echo ""
echo "--- 5. Accessibilité HTTPS ---"
HTTP_CODE=$(curl --silent --insecure --max-time 15 \
    --output /dev/null --write-out "%{http_code}" \
    "https://${TEST_VM_IP}/" 2>/dev/null || echo "000")
if [[ "${HTTP_CODE}" =~ ^(200|301|302)$ ]]; then
    pass "HTTPS répond (HTTP ${HTTP_CODE})"
elif [[ "${HTTP_CODE}" == "000" ]]; then
    fail "HTTPS inaccessible (timeout ou connexion refusée)"
else
    warn "HTTPS répond avec HTTP ${HTTP_CODE} — à investiguer"
fi

# ---- Résultats ----
echo ""
echo "========================================"
echo " Résultats Smoke (Niveau 1)"
echo " PASS: ${PASS} | FAIL: ${FAIL} | WARN: ${WARN}"
echo "========================================"
echo ""
if [[ ${FAIL} -gt 0 ]]; then
    echo "[STOP] Niveau 1 échoué — corriger avant de continuer."
    echo "       Référence : docs/adr/618-DEVOPS-strategie-debug-post-image-vm.md"
    exit 1
fi
echo "[OK] Niveau 1 validé — continuer avec : make vm-test-service"
