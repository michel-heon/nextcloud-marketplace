#!/usr/bin/env bash
# =============================================================================
# image-tests/marketplace-gallery-permissions.sh
# ADR-800 · Décision 1 — Permissions Azure Compute Gallery pour Partner Center
# ADR-601 · Nomenclature : marketplace-gallery-permissions.sh
# ADR-602 · Logique extraite du Makefile (règle des 3 lignes)
# =============================================================================
# Configure les permissions RBAC sur la gallery pour que Partner Center puisse
# accéder aux images lors de la publication Marketplace Nextcloud.
#
# Référence Microsoft :
#   https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-use-approved-base
#   Section : "Provide Partner Center with permission to your Azure Compute Gallery"
#
# Étapes :
#   1. Enregistre le RP Microsoft.PartnerCenterIngestion (crée les SPs dans le tenant)
#   2. Résout dynamiquement les Object IDs des deux SPs Microsoft
#   3. Assigne le rôle "Compute Gallery Image Reader" (cf7c76d2) sur la gallery
#
# Usage :
#   bash image-tests/marketplace-gallery-permissions.sh
#
# Variables requises (env/.env + env/.env.user) :
#   AZURE_SUBSCRIPTION_ID    — Subscription contenant la gallery
#   GALLERY_NAME             — Nom de la gallery (gal_nextcloud_marketplace)
#   GALLERY_RESOURCE_GROUP   — Resource group de la gallery (rg-nextcloud-marketplace)
#
# Idempotence : safe à relancer — les assignations existantes sont détectées et
#               ignorées (pas d'erreur, pas de doublon).
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Couleurs (ADR-611)
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Chargement des fichiers d'environnement (ADR-600)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_ROOT}/env/.env" ]]; then
    # shellcheck disable=SC1091
    set -a && source "${REPO_ROOT}/env/.env" && set +a
fi
if [[ -f "${REPO_ROOT}/env/.env.user" ]]; then
    # shellcheck disable=SC1091
    set -a && source "${REPO_ROOT}/env/.env.user" && set +a
fi

# ---------------------------------------------------------------------------
# Validation des variables requises
# ---------------------------------------------------------------------------
: "${AZURE_SUBSCRIPTION_ID:?Variable AZURE_SUBSCRIPTION_ID requise (env/.env)}"
: "${GALLERY_NAME:?Variable GALLERY_NAME requise (env/.env)}"
: "${GALLERY_RESOURCE_GROUP:?Variable GALLERY_RESOURCE_GROUP requise (env/.env)}"

# Rôle Compute Gallery Image Reader (ID stable, défini par Microsoft)
ROLE_ID="cf7c76d2-98a3-4358-a134-615aa78bf44d"
ROLE_NAME="Compute Gallery Image Reader"

# Noms des Service Principals Microsoft (résolus dynamiquement)
SP1_DISPLAY_NAME="Microsoft Partner Center Resource Provider"
SP2_DISPLAY_NAME="Compute Image Registry"

# ---------------------------------------------------------------------------
# Pré-requis : az CLI
# ---------------------------------------------------------------------------
command -v az >/dev/null 2>&1 || {
    printf "${RED}ERREUR: az cli non installé. Voir https://learn.microsoft.com/cli/azure/install-azure-cli${NC}\n"
    exit 1
}

printf "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
printf "${CYAN}  Permissions Partner Center → Azure Compute Gallery${NC}\n"
printf "${CYAN}  Référence : aka.ms/ComputeGalleryPermissions${NC}\n"
printf "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}  Subscription : %s${NC}\n" "${AZURE_SUBSCRIPTION_ID}"
printf "${BLUE}  Gallery      : %s${NC}\n" "${GALLERY_NAME}"
printf "${BLUE}  Rôle cible   : %s${NC}\n" "${ROLE_NAME}"
printf "\n"

# ---------------------------------------------------------------------------
# Définir la subscription active
# ---------------------------------------------------------------------------
printf "${CYAN}>> Sélection de la subscription %s...${NC}\n" "${AZURE_SUBSCRIPTION_ID}"
az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
printf "${GREEN}  Subscription active${NC}\n"

# ---------------------------------------------------------------------------
# Étape 1 : Enregistrement du Resource Provider Microsoft.PartnerCenterIngestion
# (crée les Service Principals Microsoft dans le tenant)
# ---------------------------------------------------------------------------
printf "\n${CYAN}>> Étape 1/3 : Enregistrement du RP Microsoft.PartnerCenterIngestion...${NC}\n"

RP_STATE=$(az provider show \
    --namespace "Microsoft.PartnerCenterIngestion" \
    --query "registrationState" \
    --output tsv 2>/dev/null || echo "NotRegistered")

if [[ "${RP_STATE}" == "Registered" ]]; then
    printf "${YELLOW}  RP déjà enregistré (état : Registered) — skip${NC}\n"
else
    printf "${CYAN}  État actuel : %s — enregistrement en cours...${NC}\n" "${RP_STATE}"
    az provider register --namespace "Microsoft.PartnerCenterIngestion" --wait
    printf "${GREEN}  RP enregistré${NC}\n"
fi

# Attendre que le RP soit fully Registered avant de continuer
MAX_WAIT=120
ELAPSED=0
while [[ "${RP_STATE}" != "Registered" && ${ELAPSED} -lt ${MAX_WAIT} ]]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    RP_STATE=$(az provider show \
        --namespace "Microsoft.PartnerCenterIngestion" \
        --query "registrationState" \
        --output tsv 2>/dev/null || echo "Unknown")
done

if [[ "${RP_STATE}" != "Registered" ]]; then
    printf "${RED}ERREUR: RP Microsoft.PartnerCenterIngestion non enregistré après %d secondes (état: %s)${NC}\n" \
        "${MAX_WAIT}" "${RP_STATE}"
    exit 1
fi
printf "${GREEN}  RP Microsoft.PartnerCenterIngestion : Registered${NC}\n"

# ---------------------------------------------------------------------------
# Étape 2 : Récupération de l'ID de ressource de la gallery
# ---------------------------------------------------------------------------
printf "\n${CYAN}>> Étape 2/3 : Résolution de l'ID de la gallery '%s'...${NC}\n" "${GALLERY_NAME}"

GALLERY_ID=$(az sig show \
    --resource-group "${GALLERY_RESOURCE_GROUP}" \
    --gallery-name "${GALLERY_NAME}" \
    --query "id" \
    --output tsv 2>/dev/null || true)

if [[ -z "${GALLERY_ID}" ]]; then
    printf "${RED}ERREUR: Gallery '%s' introuvable dans le resource group '%s'${NC}\n" \
        "${GALLERY_NAME}" "${GALLERY_RESOURCE_GROUP}"
    printf "${RED}  Vérifiez que la gallery existe et que vous avez les droits Owner/Contributor${NC}\n"
    exit 1
fi
printf "${GREEN}  Gallery ID : %s${NC}\n" "${GALLERY_ID}"

# ---------------------------------------------------------------------------
# Fonction utilitaire : assigner le rôle de façon idempotente
# ---------------------------------------------------------------------------
assign_gallery_role() {
    local sp_display_name="$1"
    local sp_id="$2"

    # Vérifier si l'assignation existe déjà
    EXISTING=$(az role assignment list \
        --assignee "${sp_id}" \
        --role "${ROLE_ID}" \
        --scope "${GALLERY_ID}" \
        --query "length(@)" \
        --output tsv 2>/dev/null || echo "0")

    if [[ "${EXISTING}" -ge 1 ]]; then
        printf "${YELLOW}  [%s] Rôle déjà assigné — skip${NC}\n" "${sp_display_name}"
    else
        az role assignment create \
            --assignee-object-id "${sp_id}" \
            --assignee-principal-type "ServicePrincipal" \
            --role "${ROLE_ID}" \
            --scope "${GALLERY_ID}" \
            --output none
        printf "${GREEN}  [%s] Rôle '%s' assigné${NC}\n" "${sp_display_name}" "${ROLE_NAME}"
    fi
}

# ---------------------------------------------------------------------------
# Étape 3 : Assignation du rôle aux deux SPs Microsoft
# ---------------------------------------------------------------------------
printf "\n${CYAN}>> Étape 3/3 : Assignation du rôle '%s' aux SPs Microsoft...${NC}\n" "${ROLE_NAME}"

# SP1 : Microsoft Partner Center Resource Provider
printf "${CYAN}  Résolution de '%s'...${NC}\n" "${SP1_DISPLAY_NAME}"
SP1_ID=$(az ad sp list \
    --display-name "${SP1_DISPLAY_NAME}" \
    --query "[0].id" \
    --output tsv 2>/dev/null || true)

if [[ -z "${SP1_ID}" || "${SP1_ID}" == "None" ]]; then
    printf "${RED}ERREUR: SP '%s' introuvable dans le tenant.${NC}\n" "${SP1_DISPLAY_NAME}"
    printf "${RED}  Vérifiez que le RP est bien enregistré et que le SP s'est créé.${NC}\n"
    exit 1
fi
printf "${BLUE}    Object ID : %s${NC}\n" "${SP1_ID}"
assign_gallery_role "${SP1_DISPLAY_NAME}" "${SP1_ID}"

# SP2 : Compute Image Registry
printf "${CYAN}  Résolution de '%s'...${NC}\n" "${SP2_DISPLAY_NAME}"
SP2_ID=$(az ad sp list \
    --display-name "${SP2_DISPLAY_NAME}" \
    --query "[0].id" \
    --output tsv 2>/dev/null || true)

if [[ -z "${SP2_ID}" || "${SP2_ID}" == "None" ]]; then
    printf "${RED}ERREUR: SP '%s' introuvable dans le tenant.${NC}\n" "${SP2_DISPLAY_NAME}"
    printf "${RED}  Ce SP est provisionné par Microsoft — vérifiez le statut du RP.${NC}\n"
    exit 1
fi
printf "${BLUE}    Object ID : %s${NC}\n" "${SP2_ID}"
assign_gallery_role "${SP2_DISPLAY_NAME}" "${SP2_ID}"

# ---------------------------------------------------------------------------
# Vérification finale
# ---------------------------------------------------------------------------
printf "\n${CYAN}>> Vérification des assignations sur la gallery...${NC}\n"
az role assignment list \
    --scope "${GALLERY_ID}" \
    --query "[?contains(roleDefinitionId,'${ROLE_ID}')].{SP:principalName,Role:roleDefinitionName,PrincipalType:principalType}" \
    --output table 2>/dev/null

printf "\n${GREEN}✓ Permissions Partner Center configurées avec succès${NC}\n"
printf "${GREEN}  La gallery '%s' est maintenant visible dans Partner Center${NC}\n" "${GALLERY_NAME}"
printf "${BLUE}ℹ Attendu : 2 lignes 'Compute Gallery Image Reader' dans le tableau ci-dessus${NC}\n"
printf "${BLUE}ℹ Si la gallery n'apparaît toujours pas dans Partner Center, attendre 5-10 minutes${NC}\n"
