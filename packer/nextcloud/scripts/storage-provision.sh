#!/usr/bin/env bash
# storage-provision.sh — Gestion du cache Azure Blob Storage (ADR-616)
# Usage: storage-provision.sh <commande>
#
# Commandes :
#   create   — Crée le Storage Account et le container blob (idempotent)
#   upload   — Télécharge les paquets sources et les pousse vers le blob
#   verify   — Vérifie que les blobs requis sont accessibles publiquement
#   list     — Liste les blobs présents dans le container
#   urls     — Affiche les URLs publiques des blobs
#
# Variables d'environnement requises (depuis env/.env) :
#   AZURE_SUBSCRIPTION_ID
#   AZURE_LOCATION
#   NC_VERSION
#   BLOB_STORAGE_ACCOUNT_NAME
#   BLOB_STORAGE_CONTAINER
#   BLOB_STORAGE_BASE_URL
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Couleurs ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_section() { echo -e "\n${BOLD}==> $*${RESET}"; }

# --- Prérequis ----------------------------------------------------------------
require_var() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    log_error "Variable ${var} non définie. Vérifier env/.env"
    exit 1
  fi
}

check_prereqs() {
  require_var AZURE_SUBSCRIPTION_ID
  require_var AZURE_LOCATION
  require_var NC_VERSION
  require_var BLOB_STORAGE_ACCOUNT_NAME
  require_var BLOB_STORAGE_CONTAINER
  require_var BLOB_STORAGE_BASE_URL

  if ! command -v az >/dev/null 2>&1; then
    log_error "Azure CLI (az) non trouvé — installer via https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
  fi
  if ! command -v wget >/dev/null 2>&1; then
    log_error "wget non trouvé — installer via: apt-get install wget"
    exit 1
  fi
}

# ==============================================================================
# COMMANDE : create
# Crée le Storage Account et le container (idempotent — skip si existant)
# ==============================================================================
cmd_create() {
  log_section "Création du Storage Account et du container blob"
  check_prereqs

  # Récupérer le resource group de la gallery (même RG que l'infrastructure)
  local resource_group="${GALLERY_RESOURCE_GROUP:-rg-nextcloud-marketplace}"

  # 1. Storage Account
  if az storage account show \
      --name "${BLOB_STORAGE_ACCOUNT_NAME}" \
      --resource-group "${resource_group}" \
      --subscription "${AZURE_SUBSCRIPTION_ID}" \
      --output none 2>/dev/null; then
    log_ok "Storage Account '${BLOB_STORAGE_ACCOUNT_NAME}' existe déjà"
  else
    log_info "Création du Storage Account '${BLOB_STORAGE_ACCOUNT_NAME}'..."
    az storage account create \
      --name "${BLOB_STORAGE_ACCOUNT_NAME}" \
      --resource-group "${resource_group}" \
      --location "${AZURE_LOCATION}" \
      --subscription "${AZURE_SUBSCRIPTION_ID}" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --min-tls-version TLS1_2 \
      --allow-blob-public-access true \
      --output table
    log_ok "Storage Account créé"
  fi

  # 2. Container blob avec accès public en lecture (blob level)
  if az storage container show \
      --name "${BLOB_STORAGE_CONTAINER}" \
      --account-name "${BLOB_STORAGE_ACCOUNT_NAME}" \
      --auth-mode login \
      --output none 2>/dev/null; then
    log_ok "Container '${BLOB_STORAGE_CONTAINER}' existe déjà"
  else
    log_info "Création du container '${BLOB_STORAGE_CONTAINER}'..."
    az storage container create \
      --name "${BLOB_STORAGE_CONTAINER}" \
      --account-name "${BLOB_STORAGE_ACCOUNT_NAME}" \
      --auth-mode login \
      --public-access blob \
      --output table
    log_ok "Container créé avec accès public (blob)"
  fi

  log_section "Storage Account prêt : ${BLOB_STORAGE_BASE_URL}"
}

# ==============================================================================
# COMMANDE : upload
# Télécharge les paquets depuis les sources officielles et les pousse dans le blob
# ==============================================================================
cmd_upload() {
  log_section "Upload des paquets vers le blob cache"
  check_prereqs

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir:-}"' EXIT

  # --- Nextcloud ZIP ----------------------------------------------------------
  local nc_filename="nextcloud-${NC_VERSION}.zip"
  local nc_source_url="https://download.nextcloud.com/server/releases/${nc_filename}"

  # Vérifier si déjà présent dans le blob (évite le re-upload)
  if wget -q --spider "${BLOB_STORAGE_BASE_URL}/${nc_filename}" 2>/dev/null; then
    log_ok "${nc_filename} déjà présent dans le blob — skip upload"
  else
    log_info "Téléchargement de ${nc_filename} depuis la source officielle..."
    wget -q --show-progress "${nc_source_url}" -O "${tmp_dir}/${nc_filename}"

    log_info "Upload vers ${BLOB_STORAGE_ACCOUNT_NAME}/${BLOB_STORAGE_CONTAINER}/${nc_filename}..."
    az storage blob upload \
      --account-name "${BLOB_STORAGE_ACCOUNT_NAME}" \
      --container-name "${BLOB_STORAGE_CONTAINER}" \
      --name "${nc_filename}" \
      --file "${tmp_dir}/${nc_filename}" \
      --auth-mode key \
      --overwrite false \
      --output table
    log_ok "Upload de ${nc_filename} terminé"
  fi

  log_section "Upload terminé"
}

# ==============================================================================
# COMMANDE : verify
# Vérifie que les blobs requis sont accessibles publiquement via HTTP
# ==============================================================================
cmd_verify() {
  log_section "Vérification des blobs dans le cache"
  check_prereqs

  local nc_filename="nextcloud-${NC_VERSION}.zip"
  local blob_url="${BLOB_STORAGE_BASE_URL}/${nc_filename}"
  local all_ok=true

  log_info "Test d'accessibilité : ${blob_url}"
  if wget -q --spider "${blob_url}" 2>/dev/null; then
    log_ok "${nc_filename} — accessible"
  else
    log_error "${nc_filename} — INACCESSIBLE (${blob_url})"
    all_ok=false
  fi

  if [[ "${all_ok}" == "true" ]]; then
    log_ok "Tous les blobs requis sont accessibles"
  else
    log_error "Des blobs sont manquants — exécuter 'make storage-upload'"
    exit 1
  fi
}

# ==============================================================================
# COMMANDE : list
# Liste tous les blobs présents dans le container
# ==============================================================================
cmd_list() {
  log_section "Blobs dans ${BLOB_STORAGE_ACCOUNT_NAME}/${BLOB_STORAGE_CONTAINER}"
  check_prereqs

  az storage blob list \
    --account-name "${BLOB_STORAGE_ACCOUNT_NAME}" \
    --container-name "${BLOB_STORAGE_CONTAINER}" \
    --auth-mode key \
    --query "[].{nom:name, taille:properties.contentLength, modifié:properties.lastModified}" \
    --output table
}

# ==============================================================================
# COMMANDE : urls
# Affiche les URLs publiques des blobs pour documentation / vérification
# ==============================================================================
cmd_urls() {
  log_section "URLs publiques du blob cache"
  check_prereqs

  local nc_filename="nextcloud-${NC_VERSION}.zip"
  echo ""
  echo "  Nextcloud ${NC_VERSION} :"
  echo "    ${BLOB_STORAGE_BASE_URL}/${nc_filename}"
  echo ""
  echo "  Container : https://${BLOB_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${BLOB_STORAGE_CONTAINER}"
  echo ""
}

# ==============================================================================
# Point d'entrée
# ==============================================================================
COMMAND="${1:-}"

case "${COMMAND}" in
  create)  cmd_create ;;
  upload)  cmd_upload ;;
  verify)  cmd_verify ;;
  list)    cmd_list   ;;
  urls)    cmd_urls   ;;
  *)
    echo ""
    echo "Usage: $(basename "$0") <commande>"
    echo ""
    echo "  create   Crée le Storage Account et le container (idempotent)"
    echo "  upload   Pousse les paquets vers le blob cache"
    echo "  verify   Vérifie l'accessibilité des blobs requis"
    echo "  list     Liste les blobs présents"
    echo "  urls     Affiche les URLs publiques"
    echo ""
    exit 1
    ;;
esac
