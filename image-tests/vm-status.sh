#!/usr/bin/env bash
# image-tests/vm-status.sh
# Affiche l'état complet de la VM de test : existence Azure, URLs, SSH, age
#
# Usage    : bash image-tests/vm-status.sh
# Makefile : make vm-test-status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="${PROJECT_ROOT}/.image-test-state"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_env

# ---- Vérification du state file ----
if [[ ! -f "${STATE_FILE}" ]]; then
    echo ""
    echo -e "${YELLOW}[WARN]${RESET}  Aucune VM de test active (fichier d'état absent)."
    echo -e "        Créer une VM avec : ${BOLD}make vm-test-create${RESET}"
    echo ""
    exit 0
fi

source "${STATE_FILE}"

SSH_PRIVKEY="${TEST_SSH_KEY_PATH%.pub}"

# ---- Age de la VM ----
age_str=""
if [[ -n "${CREATED_AT:-}" ]]; then
    created_ts=$(date -d "${CREATED_AT}" +%s 2>/dev/null || echo "0")
    now_ts=$(date +%s)
    age_sec=$(( now_ts - created_ts ))
    age_h=$(( age_sec / 3600 ))
    age_m=$(( (age_sec % 3600) / 60 ))
    age_str="${age_h}h ${age_m}m"
fi

echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  VM de test — Statut${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════════${RESET}"
echo ""

# ---- Infos state file ----
echo -e "${CYAN}── State file (.image-test-state)${RESET}"
echo -e "   VM           : ${BOLD}${TEST_VM_NAME}${RESET}"
echo -e "   Resource Group : ${TEST_RG}"
echo -e "   IP publique  : ${BOLD}${TEST_VM_IP}${RESET}"
echo -e "   Image version: v${IMAGE_VERSION:-?}"
echo -e "   Créée le     : ${CREATED_AT:-inconnu}${age_str:+  (age: ${age_str})}"
if [[ -n "${TEST_VM_FQDN:-}" ]]; then
    echo -e "   FQDN         : ${TEST_VM_FQDN}"
fi
echo ""

# ---- URLs d'accès ----
echo -e "${CYAN}── URLs${RESET}"
echo -e "   HTTP   : http://${TEST_VM_IP}     (→ redirige vers HTTPS)"
echo -e "   HTTPS  : ${BOLD}https://${TEST_VM_IP}${RESET}"
if [[ -n "${TEST_VM_FQDN:-}" ]]; then
    echo -e "   HTTPS  : ${BOLD}https://${TEST_VM_FQDN}${RESET}"
fi
echo ""

# ---- Commande SSH ----
echo -e "${CYAN}── SSH${RESET}"
echo -e "   ${BOLD}ssh -i ${SSH_PRIVKEY} ${TEST_ADMIN_USER}@${TEST_VM_IP}${RESET}"
echo ""

# ---- État Azure (az vm get-instance-view) ----
echo -e "${CYAN}── État Azure${RESET}"
VM_JSON=$(az vm get-instance-view \
    --resource-group "${TEST_RG}" \
    --name "${TEST_VM_NAME}" \
    --query "{powerState:instanceView.statuses[1].displayStatus, provState:provisioningState}" \
    -o json 2>/dev/null) || VM_JSON=""

if [[ -z "${VM_JSON}" || "${VM_JSON}" == "null" ]]; then
    echo -e "   ${RED}[ABSENT]${RESET}  La VM n'existe pas (ou le RG a été supprimé)"
else
    POWER_STATE=$(echo "${VM_JSON}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('powerState','?'))" 2>/dev/null || echo "?")
    PROV_STATE=$(echo  "${VM_JSON}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('provState','?'))"  2>/dev/null || echo "?")

    if [[ "${POWER_STATE}" == "VM running" ]]; then
        echo -e "   Power state  : ${GREEN}${BOLD}${POWER_STATE}${RESET}"
    else
        echo -e "   Power state  : ${YELLOW}${POWER_STATE}${RESET}"
    fi
    echo -e "   Provisioning : ${PROV_STATE}"

    # Taille + OS disk depuis az vm show
    VM_DETAILS=$(az vm show \
        --resource-group "${TEST_RG}" \
        --name "${TEST_VM_NAME}" \
        --query "{size:hardwareProfile.vmSize, osDisk:storageProfile.osDisk.diskSizeGb}" \
        -o json 2>/dev/null) || VM_DETAILS=""
    if [[ -n "${VM_DETAILS}" ]]; then
        VM_SIZE=$(echo "${VM_DETAILS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('size','?'))" 2>/dev/null || echo "?")
        OS_DISK=$(echo "${VM_DETAILS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('osDisk','?'))" 2>/dev/null || echo "?")
        echo -e "   Taille VM    : ${VM_SIZE}"
        echo -e "   Disque OS    : ${OS_DISK} Go"
    fi
fi
echo ""

# ---- Joignabilité HTTP/HTTPS ----
echo -e "${CYAN}── Joignabilité réseau${RESET}"

http_code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "http://${TEST_VM_IP}" 2>/dev/null || echo "---")
https_code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "https://${TEST_VM_IP}" 2>/dev/null || echo "---")

_fmt_code() {
    local code="$1" label="$2"
    if [[ "${code}" =~ ^(200|301|302)$ ]]; then
        echo -e "   ${label}: ${GREEN}${code}${RESET}"
    elif [[ "${code}" == "---" ]]; then
        echo -e "   ${label}: ${RED}injoignable (timeout)${RESET}"
    else
        echo -e "   ${label}: ${YELLOW}${code}${RESET}"
    fi
}

_fmt_code "${http_code}"  "HTTP  (80)  "
_fmt_code "${https_code}" "HTTPS (443) "

if [[ -n "${TEST_VM_FQDN:-}" ]]; then
    fqdn_code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "https://${TEST_VM_FQDN}" 2>/dev/null || echo "---")
    _fmt_code "${fqdn_code}" "HTTPS FQDN  "
fi
echo ""

# ---- Alerte coût ----
if [[ -n "${age_str}" && ${age_h} -ge 4 ]]; then
    echo -e "${YELLOW}[WARN]${RESET}  VM active depuis ${age_str} — penser à faire ${BOLD}make vm-test-delete${RESET} pour éviter des coûts inutiles."
    echo ""
fi

echo -e "${BOLD}════════════════════════════════════════════════════════${RESET}"
echo ""
