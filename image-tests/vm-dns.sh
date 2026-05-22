#!/usr/bin/env bash
# image-tests/vm-dns.sh
# Assigne un nom DNS à l'IP publique de la VM de test et enregistre le FQDN
# dans le state file.  Ajoute ensuite le FQDN comme domaine de confiance
# Nextcloud (trusted_domains) via occ.
#
# Prérequis : .image-test-state doit exister (make vm-test-create)
#
# Résultat   : .image-test-state enrichi avec TEST_VM_FQDN
#
# Usage      : bash image-tests/vm-dns.sh
# Makefile   : make vm-test-dns-assign
#
# Le label DNS généré suit le pattern : nc-test-v{version avec . → -}
#   ex. v0.1.3 → nc-test-v0-1-3
#   FQDN : nc-test-v0-1-3.<region>.cloudapp.azure.com

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="${PROJECT_ROOT}/.image-test-state"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_env
load_state

info "=== Assignation du nom DNS à la VM de test ==="
info "  VM      : ${TEST_VM_NAME}"
info "  RG      : ${TEST_RG}"
info "  IP      : ${TEST_VM_IP}"
info "  Version : v${IMAGE_VERSION}"
echo ""

# --- Générer le label DNS ---
# Format: nc-test-v<version> avec . remplacé par -
# ex. 0.1.3 → nc-test-v0-1-3
DNS_LABEL="nc-test-v${IMAGE_VERSION//./-}"
info "Label DNS cible : ${DNS_LABEL}"

# --- Obtenir le nom de la ressource IP publique ---
info "Récupération du nom de la ressource IP publique..."
PIP_NAME=$(az vm list-ip-addresses \
    --resource-group "${TEST_RG}" \
    --name "${TEST_VM_NAME}" \
    --query "[0].virtualMachine.network.publicIpAddresses[0].name" \
    -o tsv)

if [[ -z "${PIP_NAME}" ]]; then
    err "Impossible de récupérer le nom de l'IP publique pour ${TEST_VM_NAME}"
    exit 1
fi
info "Ressource IP publique : ${PIP_NAME}"

# --- Assigner le label DNS ---
info "Assignation du label DNS '${DNS_LABEL}' à ${PIP_NAME}..."
FQDN=$(az network public-ip update \
    --resource-group "${TEST_RG}" \
    --name "${PIP_NAME}" \
    --dns-name "${DNS_LABEL}" \
    --query "dnsSettings.fqdn" \
    -o tsv)

if [[ -z "${FQDN}" ]]; then
    err "Échec de l'assignation DNS — FQDN vide"
    exit 1
fi
ok "FQDN assigné : ${FQDN}"

# --- Ajouter le FQDN comme domaine de confiance Nextcloud ---
info "Ajout du FQDN comme trusted_domain Nextcloud (index 1)..."
SSH_PRIVKEY="${TEST_SSH_KEY_PATH%.pub}"
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
    -i "${SSH_PRIVKEY}" \
    "${TEST_ADMIN_USER}@${TEST_VM_IP}" \
    "sudo -u www-data php /var/www/nextcloud/occ config:system:set \
        trusted_domains 1 --value=\"${FQDN}\"" 2>/dev/null

ok "Domaine de confiance enregistré dans Nextcloud : ${FQDN}"

# --- Mettre à jour le state file ---
# Supprimer une éventuelle ligne TEST_VM_FQDN existante puis la réécrire
tmp_state=$(mktemp)
grep -v "^TEST_VM_FQDN=" "${STATE_FILE}" > "${tmp_state}" || true
echo "TEST_VM_FQDN=${FQDN}" >> "${tmp_state}"
mv "${tmp_state}" "${STATE_FILE}"
chmod 600 "${STATE_FILE}"
ok "State file mis à jour : TEST_VM_FQDN=${FQDN}"

# --- Résumé ---
echo ""
ok "=== Nom DNS assigné avec succès ==="
echo ""
echo -e "${BOLD}  FQDN  :${RESET} ${FQDN}"
echo -e "${BOLD}  HTTPS :${RESET} https://${FQDN}"
echo ""
echo "  Prochaine étape : make vm-test-dns-e2e"
