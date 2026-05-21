---
adr: 602
title: "Makefile comme Orchestrateur de Scripts"
status: "accepted"
date: 2026-02-21
classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "medium"
  quality: ["maintainability", "usability"]
  reversibility: "moderate"
  scope: "tactical"
  tech_areas: ["automation", "devops", "orchestration", "bash", "packer", "makefile"]
tags: ["makefile", "orchestration", "automation", "devops", "packer", "vm"]
stakeholders: ["@devops-team", "@dev-team"]
effort: "low"
related_issues: []
related_adrs: [601, 600, 608]
replaces: null
superseded_by: null
---

# ADR 602: Makefile comme Orchestrateur de Scripts

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-02-21 |
| **Impact** | 🟡 Moyen (workflow développeur) |
| **Domaine** | DevOps |
| **Réversibilité** | 🟡 Modérée |
| **Portée** | Projet complet |

## 🎯 Contexte

Le projet smw-marketplace comprend plusieurs types d'opérations distinctes :
- **Build image VM** : Construction Packer, validation, publication Marketplace
- **Provisioning MediaWiki : Installation Apache, MySQL, PHP-FPM, MediaWiki et extensions SMW
- **Tests et validation** : Smoke tests VM, certification Marketplace, TLS checks
- **Infrastructure Azure** : Gestion Resource Groups, images, déploiements test

**Problèmes sans orchestration** :
- Développeurs doivent mémoriser les noms exact et les arguments de chaque script
- Dépendances entre scripts non documentées (ex: bootstrap avant packer build)
- Pas de guide unifié pour découvrir les commandes disponibles
- Courbe d'apprentissage élevée pour nouveaux contributeurs

## 💡 Décision

**Nous adoptons Makefile comme couche d'orchestration standard pour l'ensemble du projet.**

Le Makefile racine :
- **Expose une interface simple** : `make <commande>` au lieu de `./scripts/nom-complexe.sh --arg1`
- **Documente automatiquement** : `make help` affiche toutes les commandes disponibles
- **Valide les prérequis** : Vérifie configuration avant exécution
- **Enchaîne les dépendances** : `make vm-build` s'assure que `setup` est exécuté avant

### Structure Standard du Makefile

```makefile
# Makefile - smw-marketplace
# Orchestration construction VM MediaWiki (SMW) pour Azure Marketplace

.PHONY: help setup clean \
        vm-build vm-validate vm-smoke-test \
        smw-install wiki-test \
        tls-validate \
        marketplace-validate marketplace-publish

# Variables
SCRIPTS_DIR := scripts
ENV_GENERATED := env/generated/config.make
PACKER_TEMPLATE := vm/packer/server-vm.pkr.hcl
PACKER_VARS := env/generated/packer-vars.json

# Couleurs
BLUE  := \033[0;34m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RED   := \033[0;31m
NC    := \033[0m

# Inclure variables générées (après bootstrap.sh)
-include $(ENV_GENERATED)

##@ Aide

help: ## Afficher cette aide
	@echo "$(BLUE)══════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  smw-marketplace — Azure Marketplace VM Builder    $(NC)"
	@echo "$(BLUE)══════════════════════════════════════════════════════$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Configuration & Setup

setup: ## Configurer l'environnement (à exécuter en premier)
	@echo "$(BLUE)Configuration environnement...$(NC)"
	@if [ ! -f "env/.env.dev.user" ]; then \
		echo "$(YELLOW)⚠️  Copier env/.env.dev.user.example vers env/.env.dev.user et remplir les valeurs$(NC)"; \
		exit 1; \
	fi
	@./bootstrap.sh
	@echo "$(GREEN)✅ Configuration générée dans env/generated/$(NC)"

check-env: ## Vérifier que la configuration est présente
	@if [ ! -f "$(ENV_GENERATED)" ]; then \
		echo "$(RED)❌ Configuration manquante. Exécuter: make setup$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Configuration OK$(NC)"

##@ Construction Image VM

vm-build: check-env ## Construire l'image VM MediaWiki avec Packer
	@echo "$(BLUE)Construction image VM MediaWiki (SMW)...$(NC)"...$(NC)"
	@echo "$(BLUE)Version SMW: $(SMW_VERSION) | Version MediaWiki: $(MEDIAWIKI_VERSION) | Région: $(AZURE_LOCATION)$(NC)"
	@packer init $(PACKER_TEMPLATE)
	@packer build -var-file=$(PACKER_VARS) $(PACKER_TEMPLATE)
	@echo "$(GREEN)✅ Image VM construite$(NC)"

vm-validate: check-env ## Valider le template Packer (sans builder)
	@packer validate -var-file=$(PACKER_VARS) $(PACKER_TEMPLATE)
	@echo "$(GREEN)✅ Template Packer valide$(NC)"

vm-inspect: check-env ## Inspecter le template Packer (liste provisioners)
	@packer inspect $(PACKER_TEMPLATE)

vm-smoke-test: check-env ## Exécuter smoke tests sur VM déployée
	@$(SCRIPTS_DIR)/vm-smoke-test.sh

##@ Tests & Validation

tls-validate: ## Valider la configuration TLS de la VM
	@$(SCRIPTS_DIR)/tls-validate.sh

wiki-test: ## Tester que MediaWiki répond correctement (endpoint check) (endpoint check)
	@$(SCRIPTS_DIR)/server-test.sh

smw-test: ## Tester que Semantic MediaWiki est opérationnel
	@$(SCRIPTS_DIR)/smw-test.sh

##@ Azure Marketplace

marketplace-validate: check-env ## Valider conformité Azure Marketplace
	@echo "$(BLUE)Validation conformité Azure Marketplace...$(NC)"
	@$(SCRIPTS_DIR)/marketplace-validate.sh
	@echo "$(GREEN)✅ Validation Marketplace terminée$(NC)"

marketplace-publish: check-env ## Publier l'offre sur Azure Marketplace
	@echo "$(YELLOW)⚠️  Publication Azure Marketplace - Confirmer? [y/N]$(NC)"
	@read confirm && [ "$$confirm" = "y" ] || exit 1
	@$(SCRIPTS_DIR)/marketplace-publish.sh

##@ Azure Infrastructure

azure-rg-create: check-env ## Créer le Resource Group de build
	@az group create --name $(AZURE_RESOURCE_GROUP) --location $(AZURE_LOCATION)
	@echo "$(GREEN)✅ Resource Group créé: $(AZURE_RESOURCE_GROUP)$(NC)"

azure-rg-clean: check-env ## Supprimer le Resource Group de build
	@echo "$(YELLOW)⚠️  Suppression $(AZURE_RESOURCE_GROUP) - Confirmer? [y/N]$(NC)"
	@read confirm && [ "$$confirm" = "y" ] || exit 1
	@az group delete --name $(AZURE_RESOURCE_GROUP) --yes

##@ Utilitaires

clean: ## Nettoyer fichiers temporaires et générés
	@rm -rf env/generated/
	@rm -rf vm/packer/output_*/
	@echo "$(GREEN)✅ Nettoyage effectué$(NC)"

version: ## Afficher versions des outils
	@echo "Packer:  $$(packer version)"
	@echo "Azure CLI: $$(az version --query '"azure-cli"' -o tsv)"
	@echo "SMW: $(SMW_VERSION) | MediaWiki: $(MEDIAWIKI_VERSION)"
```

### Hiérarchie des règles

1. **Workflows réutilisables** (build, test, deploy, validate) → **doivent** passer par `make`
2. **Logique métier** → **doit** être dans un script `scripts/*.sh`, appelé par `make`
3. **One-shot** (debug ponctuel) → peut être exécuté directement, mais ne doit pas devenir une procédure implicite

### Règle de séparation : Makefile vs Scripts

**Principe fondamental** : Le Makefile est un **orchestrateur**, pas un processeur de logique.

**Règle des 3 lignes** : Si une target nécessite plus de 3 lignes de logique (boucles, conditions complexes, transformations), extraire dans un script dédié.

**Ce qui reste dans Makefile** :
```makefile
vm-build: check-env  ## Construire l'image VM
	@echo "$(BLUE)Build image...$(NC)"
	@if [ ! -f "$(PACKER_VARS)" ]; then echo "❌ Lancer make setup d'abord"; exit 1; fi
	@packer build -var-file=$(PACKER_VARS) $(PACKER_TEMPLATE)
```

**Ce qui va dans `scripts/`** :
- Logique de validation complexe (smoke tests multi-étapes)
- Appels API avec gestion d'erreurs et retries
- Parsings et transformations
- Hardening sécurité (dizaines de commandes)

**Anti-pattern (logique dans Makefile)** :
```makefile
# ❌ MAUVAIS: Logique métier inline
wiki-configure:
	@sed -i "s/WIKI_URL=.*/WIKI_URL=$(WIKI_URL)/" /opt/mediawiki/LocalSettings.php
	@if [ -d "/usr/local/server/home" ]; then \
		cp config/applicationSetup.n3 /usr/local/server/home/config/; \
		...
	fi
```

**Pattern correct** :
```makefile
# ✅ BON: Orchestrateur → script
wiki-configure: ## Configurer MediaWiki post-installation
	@$(SCRIPTS_DIR)/server-configure.sh
```

### Commandes standardisées (obligatoires)

Chaque projet/sous-répertoire avec Makefile doit implémenter :
- `make help` — Aide formatée
- `make setup` — Configuration initiale
- `make clean` — Nettoyage
- `make test` — Tests

## ⚖️ Conséquences

### ✅ Positives

| Bénéfice | Métrique |
|----------|----------|
| **Découvrabilité** | `make help` liste toutes les commandes |
| **Reproductibilité builds** | Même commande = même résultat |
| **Onboarding rapide** | Nouveau contributeur opérationnel en < 15 min |
| **Validation prérequis** | Zéro build échoué pour config manquante |

### ⚠️ Négatives & Mitigations

| Risque | Mitigation |
|--------|------------|
| Makefile complexe | Règle 3 lignes → scripts dédiés |
| Dépendance GNU Make | Disponible nativement Linux/macOS, WSL2 sur Windows |

## 🔄 Alternatives Considérées

### Just (task runner moderne)
**Avantages** : Syntaxe plus lisible que Make  
**Rejeté** : Installation supplémentaire, pas natif, communauté plus petite

### Scripts shell d'orchestration (`run.sh`)
**Rejeté** : Pas d'aide automatique, gestion dépendances manuelle, moins standard

## 🔗 Traçabilité & Liens

- [ADR-601](./601-DEVOPS-nomenclature-scripts.md) - Nomenclature scripts
- [ADR-600](./600-DEVOPS-bootstrap-configuration-management.md) - Bootstrap configuration

## 📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-02-21 | @dev-team | Création ADR-602 | Adaptation depuis og-nore/ADR-607 pour smw-marketplace |
