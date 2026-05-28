# nextcloud-marketplace — Makefile
# Orchestrateur principal des opérations du projet
# Usage: make help
#
# =============================================================================
# RAPPEL IA — ADRs à respecter lors de toute modification de ce fichier
# =============================================================================
#
# ADR 600 · Gestion de la Configuration (docs/adr/600-DEVOPS-bootstrap-configuration-management.md)
#   - Deux fichiers d'environnement (non versionnés) :
#       • `env/.env`      — variables publiques (versions, RG names, location, IDs Azure)
#                           copié depuis `env/.env.example`
#       • `env/.env.user` — surcharges locales optionnelles (ex : IMAGE_VERSION)
#                           copié depuis `env/.env.user.example`
#   - Ce Makefile inclut les deux fichiers via `-include` et exporte toutes les variables
#   - Les variables Packer sont mappées explicitement via `-var` dans chaque cible Packer
#   - L'authentification Azure utilise Azure CLI (`az login`) — pas de Service Principal
#   - NE JAMAIS commiter `env/.env` ni `env/.env.user` dans Git (dans .gitignore)
#
# ADR 601 · Nomenclature des Scripts (docs/adr/601-DEVOPS-nomenclature-scripts.md)
#   - Format obligatoire pour tous les scripts : {object}-{action}.{ext}
#       - Tout en minuscules, mots séparés par des tirets
#       - {object} au singulier : vm, nextcloud, nginx, postgresql, redis, tls, marketplace
#       - {action} en verbe infinitif : install, configure, build, validate, test, clean
#   - Exemples valides : vm-build.sh, nextcloud-configure.sh, tls-validate.sh
#   - Les cibles Makefile suivent le même format : `vm-build`, `nextcloud-test`, `tls-check`
#   - Chaque cible doit avoir un commentaire `## Description` pour apparaître dans `make help`
#
# ADR 602 · Makefile comme Orchestrateur (docs/adr/602-DEVOPS-makefile-orchestrateur.md)
#   - Le Makefile est le SEUL point d'entrée : toute opération passe par `make <cible>`
#   - `make help` auto-documente toutes les cibles via le pattern `## commentaire`
#   - Toute nouvelle opération doit être exposée via une cible Makefile (jamais un script nu)
#   - Les cibles doivent valider leurs prérequis avant exécution (ex : env-check)
#   - Les dépendances entre cibles sont déclarées explicitement (ex : build: validate env-check)
#   - Grouper les cibles par domaine avec des sections commentées (##@ Section)
#
# =============================================================================

-include env/.env
-include env/.env.user
export

PACKER_DIR    := packer/nextcloud
TERRAFORM_DIR := terraform
IMAGE_VERSION ?= 0.2.0
ENVIRONMENT   ?= dev

# VM de test E2E (peut être surchargé : make vm-ensure E2E_RG=autre-rg)
E2E_RG ?= rg-nextcloud-test
CTT     := image-tests/marketplace-ctt.sh

SHELL := /bin/bash

# ---------------------------------------------------------------------------
# Couleurs (ADR-611 — utiliser @printf, jamais @echo -e)
# ---------------------------------------------------------------------------
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
BOLD   := \033[1m
RESET  := \033[0m
NC     := \033[0m

# ---------------------------------------------------------------------------
# Macros de log (ADR-611 — utiliser $(call log_*,message) dans les targets)
# ---------------------------------------------------------------------------
define log_action
	@printf "$(CYAN)➤ $(1)$(NC)\n"
endef

define log_success
	@printf "$(GREEN)✓ $(1)$(NC)\n"
endef

define log_warning
	@printf "$(YELLOW)⚠ $(1)$(NC)\n"
endef

define log_error
	@printf "$(RED)✗ $(1)$(NC)\n"
endef

define log_info
	@printf "$(BLUE)ℹ $(1)$(NC)\n"
endef

# ---------------------------------------------------------------------------
# Variables calculées
# ---------------------------------------------------------------------------
BUILD_DATE := $(shell date +%Y%m%d)

.DEFAULT_GOAL := help

.PHONY: help init validate image-build image-build-force image-build-debug deploy tf-init tf-plan tf-apply \
        test lint clean sysprep env-check azure-login \
        infra-rg infra-gallery infra-image-def infra-create \
        storage-create storage-upload storage-verify storage-list storage-urls \
        playwright-install \
        vm-test-create vm-test-delete vm-test-ssh vm-test-status \
	vm-test-smoke vm-test-service vm-test-autotune vm-test-e2e vm-test-cert vm-test-all \
        vm-test-dns-assign vm-test-dns-e2e \
        vm-ensure vm-stop vm-start vm-delete vm-status image-id \
        vm-dns-assign vm-dns-assign-reboot vm-firstboot-reset vm-reset-admin \
        marketplace-info marketplace-validate marketplace-all marketplace-test marketplace-tests \
        marketplace-gallery-permissions

help: ## Show available targets
	@echo ""
	@echo "$(BOLD)nextcloud-marketplace$(RESET)"
	@grep -hE '^##@|^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; \
		     /^##@/ {printf "\n$(BOLD)%s$(RESET)\n", substr($$0, 4)}; \
		     /^[a-zA-Z0-9_-]+:/ {printf "  $(CYAN)%-24s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ------------------------------------------------------------
##@ Azure
# ------------------------------------------------------------

azure-login: ## Login to Azure interactively via browser (az login)
	az login
	@echo ""
	@az account show --query "{subscription:name, id:id, tenant:tenantId}" -o table

# ------------------------------------------------------------
##@ Infrastructure Azure
# ------------------------------------------------------------

infra-rg: ## Create Azure resource groups (build + gallery)
	az group create --name $(BUILD_RESOURCE_GROUP) --location $(AZURE_LOCATION) --output table
	az group create --name $(GALLERY_RESOURCE_GROUP) --location $(AZURE_LOCATION) --output table

infra-gallery: ## Create Azure Compute Gallery
	az sig create \
		--resource-group $(GALLERY_RESOURCE_GROUP) \
		--gallery-name $(GALLERY_NAME) \
		--location $(AZURE_LOCATION) \
		--output table

infra-image-def: ## Create image definition in the gallery
	az sig image-definition create \
		--resource-group $(GALLERY_RESOURCE_GROUP) \
		--gallery-name $(GALLERY_NAME) \
		--gallery-image-definition $(GALLERY_IMAGE_NAME) \
		--publisher Nextcloud \
		--offer nextcloud \
		--sku server \
		--os-type Linux \
		--os-state Generalized \
		--hyper-v-generation V2 \
		--output table

infra-create: infra-rg infra-gallery infra-image-def ## Create all Azure infrastructure prerequisites
	@echo "$(BOLD)Infrastructure Azure prête.$(RESET)"

# ------------------------------------------------------------
##@ Image — Construction
# ------------------------------------------------------------

env-check: ## Verify required environment variables are set
	@bash scripts/check-env.sh

# (Packer)

init: ## Initialize Packer plugins
	cd $(PACKER_DIR) && packer init .

validate: ## Validate Packer templates (no build)
	cd $(PACKER_DIR) && packer validate \
		-var "subscription_id=$(AZURE_SUBSCRIPTION_ID)" \
		-var "tenant_id=$(AZURE_TENANT_ID)" \
		-var "build_resource_group=$(BUILD_RESOURCE_GROUP)" \
		-var "gallery_resource_group=$(GALLERY_RESOURCE_GROUP)" \
		-var "gallery_name=$(GALLERY_NAME)" \
		-var "gallery_image_name=$(GALLERY_IMAGE_NAME)" \
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)" \
		-var "blob_storage_base_url=$(BLOB_STORAGE_BASE_URL)" \
		.

image-build: env-check validate ## Build the Nextcloud VM image
	@TMPLOG=$$(mktemp); \
	cd $(PACKER_DIR) && packer build \
		-var "subscription_id=$(AZURE_SUBSCRIPTION_ID)" \
		-var "tenant_id=$(AZURE_TENANT_ID)" \
		-var "build_resource_group=$(BUILD_RESOURCE_GROUP)" \
		-var "gallery_resource_group=$(GALLERY_RESOURCE_GROUP)" \
		-var "gallery_name=$(GALLERY_NAME)" \
		-var "gallery_image_name=$(GALLERY_IMAGE_NAME)" \
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)" \
		-var "blob_storage_base_url=$(BLOB_STORAGE_BASE_URL)" \
		. 2>&1 | tee "$$TMPLOG"; \
	EXIT=$${PIPESTATUS[0]}; \
	if [[ $$EXIT -eq 0 ]]; then \
		sed -i 's/^IMAGE_VERSION=.*/IMAGE_VERSION=$(IMAGE_VERSION)/' "$(CURDIR)/env/.env"; \
		printf "$(GREEN)✓  env/.env mis à jour : IMAGE_VERSION=$(IMAGE_VERSION)$(RESET)\n"; \
	elif grep -q "already exists in gallery" "$$TMPLOG"; then \
		printf "\n$(YELLOW)⚠  La version $(IMAGE_VERSION) existe déjà dans la gallery.$(RESET)\n\n"; \
		printf "   $(CYAN)Option 1 — Bumper la version$(RESET) (recommandé) :\n"; \
		printf "     make image-build IMAGE_VERSION=<nouvelle-version>\n\n"; \
		printf "   $(CYAN)Option 2 — Écraser la version existante$(RESET) :\n"; \
		printf "     make image-build-force\n\n"; \
	fi; \
	rm -f "$$TMPLOG"; \
	exit $$EXIT

image-build-force: env-check validate ## Build the Nextcloud VM image (force overwrite existing version)
	@cd $(PACKER_DIR) && packer build -force \
		-var "subscription_id=$(AZURE_SUBSCRIPTION_ID)" \
		-var "tenant_id=$(AZURE_TENANT_ID)" \
		-var "build_resource_group=$(BUILD_RESOURCE_GROUP)" \
		-var "gallery_resource_group=$(GALLERY_RESOURCE_GROUP)" \
		-var "gallery_name=$(GALLERY_NAME)" \
		-var "gallery_image_name=$(GALLERY_IMAGE_NAME)" \
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)" \
		-var "blob_storage_base_url=$(BLOB_STORAGE_BASE_URL)" \
		. && \
		sed -i 's/^IMAGE_VERSION=.*/IMAGE_VERSION=$(IMAGE_VERSION)/' "$(CURDIR)/env/.env" && \
		printf "$(GREEN)✓  env/.env mis à jour : IMAGE_VERSION=$(IMAGE_VERSION)$(RESET)\n"

image-build-debug: env-check ## Build the Nextcloud VM image (debug mode)
	cd $(PACKER_DIR) && PACKER_LOG=1 packer build \
		-var "subscription_id=$(AZURE_SUBSCRIPTION_ID)" \
		-var "tenant_id=$(AZURE_TENANT_ID)" \
		-var "build_resource_group=$(BUILD_RESOURCE_GROUP)" \
		-var "gallery_resource_group=$(GALLERY_RESOURCE_GROUP)" \
		-var "gallery_name=$(GALLERY_NAME)" \
		-var "gallery_image_name=$(GALLERY_IMAGE_NAME)" \
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)" \
		-var "blob_storage_base_url=$(BLOB_STORAGE_BASE_URL)" \
		-on-error=ask \
		.

# ------------------------------------------------------------
##@ Blob Storage Cache (ADR-616)
# ------------------------------------------------------------

storage-create: env-check ## Create Azure Blob Storage account and container (idempotent)
	@bash packer/nextcloud/scripts/storage-provision.sh create

storage-upload: env-check ## Upload Nextcloud packages to blob cache
	@bash packer/nextcloud/scripts/storage-provision.sh upload

storage-verify: env-check ## Verify required blobs are publicly accessible
	@bash packer/nextcloud/scripts/storage-provision.sh verify

storage-list: env-check ## List blobs present in the cache container
	@bash packer/nextcloud/scripts/storage-provision.sh list

storage-urls: ## Show public URLs of cached packages
	@bash packer/nextcloud/scripts/storage-provision.sh urls

# ------------------------------------------------------------
##@ Terraform
# ------------------------------------------------------------

tf-init: ## Initialize Terraform
	cd $(TERRAFORM_DIR) && terraform init

tf-plan: ## Terraform plan
	cd $(TERRAFORM_DIR) && terraform plan \
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)"

tf-apply: ## Terraform apply
	cd $(TERRAFORM_DIR) && terraform apply \
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)"

# ------------------------------------------------------------
##@ Qualité
# ------------------------------------------------------------

lint: ## Lint shell scripts
	@find packer/nextcloud/scripts -name "*.sh" -exec shellcheck {} \;
	@echo "Shellcheck passed."

gallery-check: env-check ## Verify IMAGE_VERSION is published in the Compute Gallery
	@az sig image-version show \
		--resource-group $(GALLERY_RESOURCE_GROUP) \
		--gallery-name $(GALLERY_NAME) \
		--gallery-image-definition $(GALLERY_IMAGE_NAME) \
		--gallery-image-version $(IMAGE_VERSION) \
		--query "{version:name, state:provisioningState, replicationState:publishingProfile.replicationMode}" \
		-o json

test: ## Run post-deployment smoke tests (HTTP/HTTPS — requires NEXTCLOUD_HOST=<ip>)
	@bash tests/test-deployment.sh

vm-check: ## Run service checks inside the VM via SSH (requires VM_SSH=user@host)
	@if [[ -z "$${VM_SSH:-}" ]]; then \
		echo "[ERROR] VM_SSH non défini. Usage : make vm-check VM_SSH=azureuser@<ip>"; \
		exit 1; \
	fi
	@ssh -o StrictHostKeyChecking=no "$${VM_SSH}" 'sudo bash -s' < tests/check-services.sh

# ------------------------------------------------------------
##@ Utilitaires
# ------------------------------------------------------------

sysprep: ## Prepare VM for imaging (run inside the VM)
	@bash packer/nextcloud/scripts/99-sysprep.sh

clean: ## Remove generated artifacts
	@find . -name "packer-manifest.json" -delete
	@find . -name "*.pkrlog" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean done."

# ------------------------------------------------------------
##@ Tests VM (ADR-700 / ADR-701)
# ------------------------------------------------------------

playwright-install: ## Installer Playwright et les navigateurs (une seule fois)
	npm install
	npx playwright install --with-deps firefox

vm-test-create: env-check ## Créer une VM de test depuis la gallery (IMAGE_VERSION)
	@bash image-tests/vm-create.sh
	@if [[ -f .image-test-state ]]; then \
		VM_IP=$$(grep '^TEST_VM_IP=' .image-test-state | cut -d= -f2); \
		printf "\n$(BOLD)$(CYAN)  → Nextcloud : https://$$VM_IP$(RESET)\n\n"; \
	fi

vm-test-delete: ## Supprimer la VM de test et son resource group
	@bash image-tests/vm-delete.sh

vm-test-ssh: ## Ouvrir une session SSH vers la VM de test
	@bash image-tests/vm-ssh.sh

vm-test-status: ## Afficher l'état de la VM de test (URLs, PowerState, joignabilité)
	@bash image-tests/vm-status.sh

vm-test-smoke: ## Tests niveau 1 — smoke (VM active, SSH, firstboot)
	@bash image-tests/smoke-test.sh

vm-test-service: ## Tests niveau 2 — services (systemd, Nextcloud, DB)
	@bash image-tests/service-check.sh

vm-test-autotune: ## Tests niveau 2 — auto-tuning post-boot (RAM -> PHP/Redis/PostgreSQL)
	@bash image-tests/autotune-check.sh

vm-test-e2e: ## Tests niveau 2 — E2E Playwright (navigateur Firefox)
	@npx playwright test --config image-tests/playwright/playwright.config.js

vm-test-cert: ## Tests niveau 3 — conformité Azure Marketplace
	@bash image-tests/marketplace-cert.sh

vm-test-all: vm-test-smoke vm-test-service vm-test-autotune vm-test-e2e vm-test-cert ## Lancer tous les niveaux de test

vm-test-dns-assign: ## Assigner un nom DNS à la VM de test et enregistrer le FQDN dans le state file
	@bash image-tests/vm-dns.sh

vm-test-dns-e2e: ## Tests E2E Playwright via nom DNS (après vm-test-dns-assign)
	@npx playwright test --config image-tests/playwright/playwright.config.js

# ------------------------------------------------------------
##@ Marketplace — Validation Azure (ADR-800)
# ------------------------------------------------------------

vm-ensure: env-check ## Créer la VM de test Nextcloud si elle n'existe pas (depuis dernière image gallery)
	$(call log_action,Vérification / création VM de test...)
	@E2E_RG=$(E2E_RG) bash image-tests/vm-create.sh

vm-stop: ## Deallocater la VM de test Nextcloud
	$(call log_action,Arrêt de la VM de test...)
	@STATE=$$(grep '^TEST_VM_NAME=' .image-test-state 2>/dev/null | cut -d= -f2); \
	az vm deallocate --resource-group $(E2E_RG) --name "$${STATE}" --no-wait

vm-start: ## Démarrer la VM de test Nextcloud
	$(call log_action,Démarrage de la VM de test...)
	@STATE=$$(grep '^TEST_VM_NAME=' .image-test-state 2>/dev/null | cut -d= -f2); \
	az vm start --resource-group $(E2E_RG) --name "$${STATE}"

vm-delete: ## Supprimer la VM de test Nextcloud et son resource group
	$(call log_action,Suppression de la VM de test...)
	@bash image-tests/vm-delete.sh

vm-status: ## Afficher l'état, l'IP et l'URL de la VM de test
	$(call log_action,Statut de la VM de test...)
	@bash image-tests/vm-status.sh

image-id: ## Afficher l'ID et la version de la dernière image gallery
	$(call log_action,Récupération de l'ID image gallery...)
	@az sig image-version list \
		--resource-group $(GALLERY_RESOURCE_GROUP) \
		--gallery-name $(GALLERY_NAME) \
		--gallery-image-definition $(GALLERY_IMAGE_NAME) \
		--query "sort_by(@, &name)[-1].{Version:name, ID:id, State:provisioningState}" \
		--output table

vm-dns-assign: ## Assigner un label DNS à l'IP publique de la VM de test
	$(call log_action,Attribution d'un label DNS à la VM de test...)
	@bash image-tests/vm-dns.sh

vm-dns-assign-reboot: ## Assigner le DNS puis rebooter la VM (auto-config via IMDS au démarrage)
	$(call log_action,Attribution DNS + redémarrage de la VM de test...)
	@bash image-tests/vm-dns.sh
	@STATE=$$(grep '^TEST_VM_NAME=' .image-test-state 2>/dev/null | cut -d= -f2); \
	az vm restart --resource-group $(E2E_RG) --name "$${STATE}"
	$(call log_success,VM redémarrée — nc-first-boot se relancera avec le FQDN)

vm-firstboot-reset: ## Effacer le sentinel + relancer nc-first-boot avec le FQDN courant
	$(call log_action,Réinitialisation de nc-first-boot sur la VM de test...)
	@bash image-tests/vm-firstboot-reset.sh

vm-reset-admin: ## Réinitialiser le mot de passe admin Nextcloud (occ user:resetpassword)
	$(call log_action,Réinitialisation du mot de passe admin Nextcloud...)
	@bash image-tests/vm-reset-admin.sh

marketplace-info: ## Afficher les infos sur la validation Marketplace CTT (ADR-800)
	@bash $(CTT) info

marketplace-validate: vm-ensure ## Valider conformité Azure Marketplace sur VM de test
	@bash $(CTT) validate

marketplace-all: vm-ensure ## Exécuter tous les tests CTT (alias validate)
	@bash $(CTT) all

marketplace-test: ## Exécuter un test CTT spécifique (TEST=nom)
	@bash $(CTT) test $(TEST)

marketplace-tests: ## Lister les tests CTT disponibles
	@bash $(CTT) list

marketplace-gallery-permissions: ## Configurer les permissions ACG pour Partner Center (ADR-800 Décision 1)
	$(call log_action,Configuration des permissions Azure Compute Gallery pour Partner Center...)
	@GALLERY_NAME=$(GALLERY_NAME) \
		GALLERY_RESOURCE_GROUP=$(GALLERY_RESOURCE_GROUP) \
		bash image-tests/marketplace-gallery-permissions.sh
	$(call log_success,Permissions gallery configurées — Partner Center peut accéder à la gallery)
