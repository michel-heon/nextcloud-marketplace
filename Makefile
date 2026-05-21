# nextcloud-marketplace — Makefile
# Orchestrateur principal des opérations du projet
# Usage: make help

-include env/.env
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

.PHONY: help init validate build build-debug deploy tf-init tf-plan tf-apply \
        test lint clean sysprep env-check

help: ## Show available targets
	@echo ""
	@echo "$(BOLD)nextcloud-marketplace$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}'
	@echo ""

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
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)" \
		.

build: env-check validate ## Build the Nextcloud VM image
	cd $(PACKER_DIR) && packer build \
		-var "image_version=$(IMAGE_VERSION)" \
		-var "environment=$(ENVIRONMENT)" \
		.

build-debug: env-check ## Build the Nextcloud VM image (debug mode)
	cd $(PACKER_DIR) && PACKER_LOG=1 packer build \
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
