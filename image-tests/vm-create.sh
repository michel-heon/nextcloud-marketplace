#!/usr/bin/env bash
# image-tests/vm-create.sh
# Crée une VM de test depuis l'image gallery IMAGE_VERSION
#
# Usage      : bash image-tests/vm-create.sh
# Dépendances: az CLI, SSH, Python3
#
# Variables depuis env/.env :
#   AZURE_SUBSCRIPTION_ID, GALLERY_RESOURCE_GROUP, GALLERY_NAME,
#   GALLERY_IMAGE_NAME, IMAGE_VERSION, AZURE_LOCATION
#
# Variables optionnelles (via image-tests/env/.env.test ou env/.env.user) :
#   TEST_RG               (défaut: rg-nextcloud-test)
#   TEST_VM_NAME          (défaut: vm-nc-test)
#   TEST_VM_SIZE          (défaut: Standard_B2s)
#   TEST_ADMIN_USER       (défaut: azureuser)
#   TEST_SSH_KEY_PATH     (défaut: ~/.ssh/id_rsa.pub)
#   TEST_NC_ADMIN_USER    (défaut: ncadmin)
#   TEST_NC_ADMIN_PASS    (requis ou défaut : changeme123!)
#   TEST_NC_DB_PASS       (défaut: dbpassword123!)
#   TEST_REDIS_PASS       (défaut: redis123!)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="${PROJECT_ROOT}/.image-test-state"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_env

# Defaults (surchargeables via image-tests/env/.env.test)
TEST_RG="${TEST_RG:-rg-nextcloud-test}"
TEST_VM_NAME="${TEST_VM_NAME:-vm-nc-test}"
TEST_VM_SIZE="${TEST_VM_SIZE:-Standard_B2s}"
TEST_ADMIN_USER="${TEST_ADMIN_USER:-azureuser}"
TEST_SSH_KEY_PATH="${TEST_SSH_KEY_PATH:-${HOME}/.ssh/id_rsa.pub}"
TEST_NC_ADMIN_USER="${TEST_NC_ADMIN_USER:-ncadmin}"
TEST_NC_ADMIN_PASS="${TEST_NC_ADMIN_PASS:-changeme123!}"
TEST_NC_DB_PASS="${TEST_NC_DB_PASS:-dbpassword123!}"
TEST_REDIS_PASS="${TEST_REDIS_PASS:-redis123!}"

# --- Validation ---
if [[ ! -f "${TEST_SSH_KEY_PATH}" ]]; then
    err "Clé SSH publique introuvable : ${TEST_SSH_KEY_PATH}"
    err "Définir TEST_SSH_KEY_PATH dans image-tests/env/.env.test"
    exit 1
fi

if [[ "${TEST_NC_ADMIN_PASS}" == "changeme123!" ]]; then
    warn "TEST_NC_ADMIN_PASS est la valeur par défaut — définir dans env/.env.user"
fi

SSH_PRIVKEY="${TEST_SSH_KEY_PATH%.pub}"
if [[ ! -f "${SSH_PRIVKEY}" ]]; then
    err "Clé SSH privée introuvable : ${SSH_PRIVKEY}"
    exit 1
fi

# --- Image reference ---
IMAGE_ID="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${GALLERY_RESOURCE_GROUP}/providers/Microsoft.Compute/galleries/${GALLERY_NAME}/images/${GALLERY_IMAGE_NAME}/versions/${IMAGE_VERSION}"

info "=== Création VM de test Nextcloud ==="
info "  Image   : ${GALLERY_IMAGE_NAME} v${IMAGE_VERSION}"
info "  VM      : ${TEST_VM_NAME} (${TEST_VM_SIZE})"
info "  RG      : ${TEST_RG} (${AZURE_LOCATION})"
echo ""

# --- Resource Group ---
info "Création du resource group ${TEST_RG}..."
az group create \
    --name "${TEST_RG}" \
    --location "${AZURE_LOCATION}" \
    --output none
ok "Resource group ${TEST_RG} prêt"

# --- Cloud-init payload ---
# Correspond à la structure attendue par nc-first-boot.sh (cloud-init/cloud-init.yaml)
CLOUD_INIT_FILE=$(mktemp /tmp/nc-test-cloudinit.XXXXXX.yaml)
trap 'rm -f "${CLOUD_INIT_FILE}"' EXIT

cat > "${CLOUD_INIT_FILE}" <<CLOUDINIT
#cloud-config
hostname: nc-test
manage_etc_hosts: true

write_files:
  - path: /etc/nextcloud/config.env
    owner: root:root
    permissions: "0600"
    content: |
      NC_ADMIN_USER=${TEST_NC_ADMIN_USER}
      NC_ADMIN_PASSWORD=${TEST_NC_ADMIN_PASS}
      NC_DB_PASSWORD=${TEST_NC_DB_PASS}
      REDIS_PASSWORD=${TEST_REDIS_PASS}
      NC_TRUSTED_DOMAIN=localhost
# nextcloud-first-boot.service est active (WantedBy=cloud-init.target)
# et demarre automatiquement apres que cloud-init.target soit atteint.
# Pas de runcmd necessaire - le demarrage manuel depuis runcmd bypasserait
# les dependances After= et risquerait un demarrage avant que postgres/redis
# soient prets.
CLOUDINIT

# --- VM creation ---
info "Démarrage de la création de la VM (peut prendre ~3 min)..."
VM_JSON=$(az vm create \
    --resource-group "${TEST_RG}" \
    --name "${TEST_VM_NAME}" \
    --image "${IMAGE_ID}" \
    --size "${TEST_VM_SIZE}" \
    --admin-username "${TEST_ADMIN_USER}" \
    --ssh-key-values "${TEST_SSH_KEY_PATH}" \
    --custom-data "${CLOUD_INIT_FILE}" \
    --public-ip-sku Standard \
    --os-disk-delete-option Delete \
    --nic-delete-option Delete \
    --output json)

PUBLIC_IP=$(echo "${VM_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['publicIpAddress'])")
ok "VM créée — IP publique : ${PUBLIC_IP}"

# --- Open HTTP and HTTPS ports ---
info "Ouverture du port 443 (HTTPS)..."
az vm open-port \
    --resource-group "${TEST_RG}" \
    --name "${TEST_VM_NAME}" \
    --port 443 \
    --priority 900 \
    --output none
ok "Port 443 ouvert"

info "Ouverture du port 80 (HTTP → redirection HTTPS)..."
az network nsg rule create \
    --resource-group "${TEST_RG}" \
    --nsg-name "${TEST_VM_NAME}NSG" \
    --name open-port-80 \
    --priority 901 \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --output none
ok "Port 80 ouvert"

# --- Wait for SSH ---
info "Attente de la disponibilité SSH (timeout : 2 min)..."
TIMEOUT=120
ELAPSED=0
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
          -i "${SSH_PRIVKEY}" \
          "${TEST_ADMIN_USER}@${PUBLIC_IP}" exit 2>/dev/null; do
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    if [[ ${ELAPSED} -ge ${TIMEOUT} ]]; then
        err "Timeout SSH après ${TIMEOUT}s — VM potentiellement non démarrée"
        exit 1
    fi
    info "  ... attente SSH (${ELAPSED}s/${TIMEOUT}s)"
done
ok "SSH accessible"

# --- Wait for firstboot ---
info "Attente du firstboot Nextcloud (sonde toutes les 15s, max 10 min)..."
TIMEOUT=600
ELAPSED=0
FIRSTBOOT_DONE=false
while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
           -i "${SSH_PRIVKEY}" \
           "${TEST_ADMIN_USER}@${PUBLIC_IP}" \
           "test -f /etc/nextcloud/.first-boot-complete" 2>/dev/null; then
        FIRSTBOOT_DONE=true
        break
    fi
    sleep 15
    ELAPSED=$((ELAPSED + 15))
    info "  ... firstboot en cours (${ELAPSED}s/${TIMEOUT}s)"
done

if [[ "${FIRSTBOOT_DONE}" == "true" ]]; then
    ok "Firstboot terminé"

    # --- Add public IP to Nextcloud trusted_domains ---
    info "Ajout de l'IP publique aux trusted_domains Nextcloud..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -i "${SSH_PRIVKEY}" \
        "${TEST_ADMIN_USER}@${PUBLIC_IP}" \
        "sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 2 --value='${PUBLIC_IP}'" 2>/dev/null \
        && ok "IP ${PUBLIC_IP} ajoutée aux trusted_domains" \
        || warn "Impossible d'ajouter l'IP aux trusted_domains — continuer manuellement"

    # --- Mettre à jour overwrite.cli.url vers l'IP publique ---
    # nc-first-boot.sh utilise NC_TRUSTED_DOMAIN=localhost → overwrite.cli.url=https://localhost
    # On corrige vers l'IP connue pour que les tests IP-based chargent les assets correctement
    info "Mise à jour de overwrite.cli.url vers l'IP publique..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        -i "${SSH_PRIVKEY}" \
        "${TEST_ADMIN_USER}@${PUBLIC_IP}" \
        "sudo -u www-data php /var/www/nextcloud/occ config:system:set overwrite.cli.url --value='https://${PUBLIC_IP}'" 2>/dev/null \
        && ok "overwrite.cli.url mis à jour : https://${PUBLIC_IP}" \
        || warn "Impossible de mettre à jour overwrite.cli.url — continuer manuellement"
else
    warn "Timeout firstboot après ${TIMEOUT}s — vérifier manuellement :"
    warn "  make vm-test-ssh"
    warn "  journalctl -u nextcloud-first-boot.service --no-pager"
fi

# --- Save state file ---
cat > "${STATE_FILE}" <<STATE
TEST_VM_NAME=${TEST_VM_NAME}
TEST_RG=${TEST_RG}
TEST_VM_IP=${PUBLIC_IP}
TEST_ADMIN_USER=${TEST_ADMIN_USER}
TEST_SSH_KEY_PATH=${TEST_SSH_KEY_PATH}
TEST_NC_ADMIN_USER=${TEST_NC_ADMIN_USER}
TEST_NC_ADMIN_PASS=${TEST_NC_ADMIN_PASS}
IMAGE_VERSION=${IMAGE_VERSION}
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATE
chmod 600 "${STATE_FILE}"

# --- Summary ---
ok "=== VM de test prête ==="
echo ""
echo -e "${BOLD}  IP publique :${RESET} ${PUBLIC_IP}"
echo -e "${BOLD}  SSH         :${RESET} ssh ${TEST_ADMIN_USER}@${PUBLIC_IP} -i ${SSH_PRIVKEY}"
echo -e "${BOLD}  HTTPS       :${RESET} https://${PUBLIC_IP}"
echo -e "${BOLD}  State file  :${RESET} ${STATE_FILE}"
echo ""
echo "  Prochaine étape : make vm-test-smoke"
