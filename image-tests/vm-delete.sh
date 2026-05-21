#!/usr/bin/env bash
# image-tests/vm-delete.sh
# Supprime la VM de test et son resource group Azure
#
# Usage: bash image-tests/vm-delete.sh
# Lit les informations depuis .image-test-state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="${PROJECT_ROOT}/.image-test-state"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_state

info "=== Suppression VM de test ==="
info "  VM    : ${TEST_VM_NAME}"
info "  RG    : ${TEST_RG}"
info "  Créée : ${CREATED_AT:-inconnu}"
echo ""

warn "Cette action supprime le resource group ${TEST_RG} et TOUTES ses ressources."
read -r -p "Confirmer la suppression ? [y/N] : " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
    info "Annulé."
    exit 0
fi

info "Suppression du resource group ${TEST_RG} (opération asynchrone)..."
az group delete \
    --name "${TEST_RG}" \
    --yes \
    --no-wait

ok "Suppression lancée en arrière-plan pour ${TEST_RG}"
info "  Suivre avec : az group show --name ${TEST_RG} --query provisioningState -o tsv"

rm -f "${STATE_FILE}"
ok "Fichier d'état supprimé : ${STATE_FILE}"
echo ""
echo "  La VM de test a été supprimée."
echo "  Pour créer une nouvelle VM : make vm-test-create"
