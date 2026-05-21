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
IMAGE_VERSION ?= 0.1.0
ENVIRONMENT   ?= dev

# Colors
CYAN  := \033[36m
RESET := \033[0m
BOLD  := \033[1m

.DEFAULT_GOAL := help

.PHONY: help init validate image-build image-build-debug deploy tf-init tf-plan tf-apply \
        test lint clean sysprep env-check azure-login \
        infra-rg infra-gallery infra-image-def infra-create

help: ## Show available targets
	@echo ""
	@echo "$(BOLD)nextcloud-marketplace$(RESET)"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ------------------------------------------------------------
# Azure
# ------------------------------------------------------------

azure-login: ## Login to Azure interactively via browser (az login)
	az login
	@echo ""
	@az account show --query "{subscription:name, id:id, tenant:tenantId}" -o table

# ------------------------------------------------------------
# Azure Infrastructure
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
# Environment
# ------------------------------------------------------------

env-check: ## Verify required environment variables are set
	@bash scripts/check-env.sh

# ------------------------------------------------------------
# Packer
# ------------------------------------------------------------

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
		.

image-build: env-check validate ## Build the Nextcloud VM image
	cd $(PACKER_DIR) && packer build \
		-var "subscription_id=$(AZURE_SUBSCRIPTION_ID)" \
		-var "tenant_id=$(AZURE_TENANT_ID)" \
		-var "build_resource_group=$(BUILD_RESOURCE_GROUP)" \
		-var "gallery_resource_group=$(GALLERY_RESOURCE_GROUP)" \
		-var "gallery_name=$(GALLERY_NAME)" \
		-var "gallery_image_name=$(GALLERY_IMAGE_NAME)" \
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)" \
		.

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
		-on-error=ask \
		.

# ------------------------------------------------------------
# Terraform
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
# Quality
# ------------------------------------------------------------

lint: ## Lint shell scripts
	@find packer/nextcloud/scripts -name "*.sh" -exec shellcheck {} \;
	@echo "Shellcheck passed."

test: ## Run post-deployment smoke tests
	@bash tests/test-deployment.sh

# ------------------------------------------------------------
# Utilities
# ------------------------------------------------------------

sysprep: ## Prepare VM for imaging (run inside the VM)
	@bash packer/nextcloud/scripts/99-sysprep.sh

clean: ## Remove generated artifacts
	@find . -name "packer-manifest.json" -delete
	@find . -name "*.pkrlog" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean done."
