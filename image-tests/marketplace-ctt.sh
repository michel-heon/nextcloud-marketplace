#!/usr/bin/env bash
# =============================================================================
# image-tests/marketplace-ctt.sh
# Validation conformité Azure Marketplace — Nextcloud (ADR-800)
#
# ADR-602 : Logique extraite du Makefile, orchestrée par sous-commande
# ADR-800 : Publication Azure Marketplace VM Offer
#
# Sous-commandes :
#   info                   Afficher les infos sur la validation CTT
#   validate [vm_name]     Exécuter tous les tests de conformité
#   all [vm_name]          Alias pour validate
#   test <nom> [vm_name]   Exécuter un test CTT spécifique (liste via 'list')
#   list                   Lister les tests CTT disponibles
#
# Usage depuis le Makefile :
#   make marketplace-validate
#   make marketplace-test TEST=ssh_root_login
#   make marketplace-tests
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Couleurs ANSI (ADR-611)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Tests CTT disponibles (cohérent avec les catégories de marketplace-cert.sh)
AVAILABLE_TESTS=(
    ssh_root_login
    ssh_password_auth
    ufw_active
    ufw_ports
    tls_version
    credentials
    waagent
    maintenance_mode
    attack_surface
    linux_azure_requirements
    image_cleanliness
)

# =============================================================================
# show_info — Afficher les infos sur la validation Marketplace CTT
# =============================================================================
show_info() {
    printf "\n${BOLD}${CYAN}Azure Marketplace Certification — Nextcloud (ADR-800)${NC}\n"
    printf "${CYAN}══════════════════════════════════════════════════════${NC}\n\n"
    printf "Ce script valide la conformité aux exigences Microsoft Azure Marketplace.\n\n"
    printf "${BOLD}Critères couverts :${NC}\n"
    printf "  • SSH key-only (PermitRootLogin no, PasswordAuthentication no)\n"
    printf "  • Pare-feu UFW actif (ports 22 et 443 uniquement)\n"
    printf "  • TLS 1.2+ (pas de TLSv1.0/1.1)\n"
    printf "  • Pas de credentials hardcodés résiduels\n"
    printf "  • Généralisation waagent (DeleteRootPassword, RegenerateSshHostKeyPair)\n"
    printf "  • Mode maintenance Nextcloud désactivé\n"
    printf "  • Pas de surfaces d'attaque exposées (phpinfo, .env, HTTP non-filtré)\n"
    printf "\n"
    printf "${BOLD}Usage :${NC}\n"
    printf "  make marketplace-validate           # Valide sur VM de test active\n"
    printf "  make marketplace-test TEST=<nom>    # Test individuel (voir 'list')\n"
    printf "  make marketplace-tests              # Lister les tests disponibles\n"
    printf "\n"
    printf "${BOLD}Prérequis :${NC}\n"
    printf "  • VM de test créée et démarrée  : make vm-ensure\n"
    printf "  • Fichier d'état présent        : .image-test-state\n"
    printf "\n"
}

# =============================================================================
# list_tests — Lister les tests CTT disponibles
# =============================================================================
list_tests() {
    printf "\n${BOLD}${CYAN}Tests CTT disponibles — Nextcloud Marketplace :${NC}\n\n"
    printf "  ${GREEN}%-26s${NC} %s\n" "ssh_root_login"     "SSH: PermitRootLogin désactivé"
    printf "  ${GREEN}%-26s${NC} %s\n" "ssh_password_auth"  "SSH: PasswordAuthentication désactivée"
    printf "  ${GREEN}%-26s${NC} %s\n" "ufw_active"         "Pare-feu UFW actif"
    printf "  ${GREEN}%-26s${NC} %s\n" "ufw_ports"          "Ports 22 et 443 uniquement exposés"
    printf "  ${GREEN}%-26s${NC} %s\n" "tls_version"        "TLS 1.2+ activé, pas de TLSv1.0/1.1"
    printf "  ${GREEN}%-26s${NC} %s\n" "credentials"        "Pas de credentials hardcodés résiduels"
    printf "  ${GREEN}%-26s${NC} %s\n" "waagent"            "Généralisation waagent configurée"
    printf "  ${GREEN}%-26s${NC} %s\n" "maintenance_mode"   "Mode maintenance Nextcloud désactivé"
    printf "  ${GREEN}%-26s${NC} %s\n" "attack_surface"     "Pas de surfaces d'attaque exposées"
    printf "\n"
}

# =============================================================================
# run_validate — Exécuter la suite complète via marketplace-cert.sh
# =============================================================================
run_validate() {
    exec bash "${SCRIPT_DIR}/marketplace-cert.sh"
}

# =============================================================================
# run_single_test — Exécuter un test CTT spécifique
# Délègue à marketplace-cert.sh en filtrant la sortie par catégorie
# =============================================================================
run_single_test() {
    local test_name="${1:-}"

    if [[ -z "${test_name}" ]]; then
        printf "${RED}✗ Nom du test requis${NC}\n\n"
        list_tests
        exit 1
    fi

    # Vérifier que le test existe
    local valid=false
    for t in "${AVAILABLE_TESTS[@]}"; do
        if [[ "${t}" == "${test_name}" ]]; then
            valid=true
            break
        fi
    done

    if [[ "${valid}" == false ]]; then
        printf "${RED}✗ Test inconnu : ${test_name}${NC}\n\n"
        list_tests
        exit 1
    fi

    printf "${CYAN}➤ Test individuel : ${BOLD}${test_name}${NC}\n"
    printf "${YELLOW}⚠  Note : le script complet de certification est exécuté — les résultats couvrent tous les tests.${NC}\n\n"
    exec bash "${SCRIPT_DIR}/marketplace-cert.sh"
}

# =============================================================================
# Main dispatch
# =============================================================================
case "${1:-}" in
    info)
        show_info
        ;;
    validate)
        run_validate
        ;;
    all)
        run_validate
        ;;
    test)
        run_single_test "${2:-}"
        ;;
    list)
        list_tests
        ;;
    *)
        printf "Usage: %s <commande> [options]\n\n" "$(basename "$0")"
        printf "${BOLD}Commandes disponibles :${NC}\n"
        printf "  ${GREEN}info${NC}                       Afficher infos CTT (ADR-800)\n"
        printf "  ${GREEN}validate${NC}                   Exécuter tous les tests de conformité\n"
        printf "  ${GREEN}all${NC}                        Alias pour validate\n"
        printf "  ${GREEN}test${NC} <nom>                 Exécuter un test spécifique\n"
        printf "  ${GREEN}list${NC}                       Lister les tests disponibles\n"
        printf "\n"
        exit 1
        ;;
esac
