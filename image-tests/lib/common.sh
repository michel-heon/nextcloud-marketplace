#!/usr/bin/env bash
# image-tests/lib/common.sh
# Bibliothèque partagée des scripts de test image (ADR-604)
#
# Sourcer ce fichier APRÈS avoir défini PROJECT_ROOT :
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
#   source "${PROJECT_ROOT}/image-tests/lib/common.sh"

# ---- Couleurs (ADR-611) ----
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
RED='\033[31m';  BOLD='\033[1m';   RESET='\033[0m'

# ---- Logging (info/ok/warn/err pour vm-create, vm-delete, vm-ssh) ----
info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET}   $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ---- Compteurs de tests + fonctions (smoke-test, service-check, marketplace-cert) ----
PASS=0; FAIL=0; WARN=0

pass() { echo -e "${GREEN}[PASS]${RESET} $*"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}[FAIL]${RESET} $*";   FAIL=$((FAIL+1)); }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; WARN=$((WARN+1)); }

print_summary() {
    echo ""
    echo "========================================"
    if [[ ${FAIL} -eq 0 ]]; then
        echo -e "${GREEN}${BOLD} RÉSULTAT : ${PASS} passé(s), ${FAIL} échoué(s), ${WARN} avertissement(s)${RESET}"
    else
        echo -e "${RED}${BOLD} RÉSULTAT : ${PASS} passé(s), ${FAIL} échoué(s), ${WARN} avertissement(s)${RESET}"
    fi
    echo "========================================"
    [[ ${FAIL} -gt 0 ]] && return 1 || return 0
}

# ---- Chargement de l'environnement (ADR-600) ----
# 3 couches : env/.env → env/.env.user → image-tests/env/.env.test
# Toutes optionnelles (|| true) pour permettre un usage sans fichier local.
load_env() {
    local root="${PROJECT_ROOT:?PROJECT_ROOT doit être défini avant de sourcer common.sh}"
    # Couche 1 : config projet (public)
    # shellcheck source=../../env/.env
    source "${root}/env/.env" 2>/dev/null || true
    # Couche 2 : surcharges personnelles (privé)
    # shellcheck source=../../env/.env.user
    source "${root}/env/.env.user" 2>/dev/null || true
    # Couche 3 : config test spécifique (privé)
    # shellcheck source=../env/.env.test
    source "${root}/image-tests/env/.env.test" 2>/dev/null || true
}

# ---- Chargement du fichier d'état de la VM de test ----
# Échoue proprement si la VM n'a pas encore été créée.
load_state() {
    local state="${PROJECT_ROOT}/.image-test-state"
    if [[ ! -f "${state}" ]]; then
        err "Fichier d'état introuvable : ${state}"
        err "Créer la VM avec : make vm-test-create"
        exit 1
    fi
    # shellcheck source=../../.image-test-state
    source "${state}"
}

# ---- SSH helper ----
# Prérequis : load_state() doit avoir été appelé (TEST_SSH_KEY_PATH, TEST_ADMIN_USER, TEST_VM_IP)
ssh_run() {
    local privkey="${TEST_SSH_KEY_PATH%.pub}"
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=15 \
        -i "${privkey}" \
        "${TEST_ADMIN_USER}@${TEST_VM_IP}" "$@" 2>/dev/null
}
