---
adr: 600
title: "Gestion de la Configuration (make config)"
status: "accepted"
date: 2026-02-21
superseded_by: null
replaces: null
related_adrs: [601, 602, 608]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "medium"
  quality:
    - "maintainability"
    - "security"
    - "usability"
  reversibility: "moderate"
  scope: "tactical"
  tech_areas:
    - "python"
    - "configuration"
    - "dotenv"
    - "packer"
    - "azure"

tags: ["configuration", "environment", "secrets", "config", "devops", "mediawiki"]
stakeholders: ["@dev-team", "@devops-team"]
effort: "low"
---

# ADR 600: Gestion de la Configuration (make config)

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-02-21 |
| **Stakeholders** | @dev-team, @devops-team |
| **Impact** | 🟡 Moyen (configuration projet) |
| **Effort Implémentation** | 🟢 Faible |
| **Risque Technique** | 🟢 Faible |

## Statut

✅ Accepté

## Date

2026-02-21

## ⚠️ Règle Critique: Non-Édition Manuelle des Fichiers Générés

**INTERDICTION ABSOLUE**: Les fichiers dans `env/generated/` sont **auto-générés** et **ne doivent JAMAIS être édités manuellement**.

### Pourquoi?

1. **Écrasement garanti**: Toute modification sera **perdue** au prochain `make config` ou `make setup`
2. **Incohérence**: Divergence entre source (`env/.env.dev*`) et sortie (`env/generated/*`)
3. **Risque de sécurité**: Secrets modifiés localement peuvent être mal propagés dans les builds Packer

### Workflow Correct

```bash
# ✅ CORRECT: Éditer la source, puis régénérer
nano env/.env.dev              # Pour config publique (URLs, versions, IDs Azure)
nano env/.env.dev.user         # Pour secrets (SAS tokens, App Registration)
make config                    # Régénérer les fichiers

# ❌ INCORRECT: Éditer directement les fichiers générés
nano env/generated/config.env  # INTERDIT - Sera écrasé
nano env/generated/.env        # INTERDIT - Sera écrasé
nano env/generated/config.make # INTERDIT - Sera écrasé
```

## Contexte

Le projet smw-marketplace nécessite une gestion sécurisée de la configuration pour :

- **Scripts de build Packer** : IDs Azure, credentials pour construction image VM
- **Scripts de déploiement** : Subscription Azure, Resource Group, région
- **Configuration MediaWiki : URLs Apache, MySQL, extensions SMW
- **Secrets Azure Marketplace** : App Registration, SAS tokens, Publisher ID

### Problèmes identifiés

1. **Secrets exposés** : Credentials Azure présents en clair dans fichiers versionnés
2. **Duplication de configuration** : Multiples formats requis (Bash, Makefile, Packer variables)
3. **Complexité d'installation** : Processus manuel sujet aux erreurs
4. **Substitution de variables** : Besoin d'expansion de variables (`${VAR}`) dans les templates Packer

### Contraintes

- Secrets ne doivent **jamais** être versionnés dans Git (Azure credentials, App Registration)
- Support de multiples formats (scripts Bash, Makefile, variables Packer JSON)
- Configuration doit être simple pour nouveaux contributeurs
- Validation automatique des variables critiques avant tout build

## Décision

Adopter un système de configuration en **deux couches** avec génération via `bootstrap.py` :

### Architecture

```
env/
├── .env.dev                    # Variables PUBLIQUES versionnées
│                               # (versions SMW, région Azure, noms ressources)
├── .env.dev.user              # Secrets PRIVÉS (NON versionnés)
│                               # (Azure credentials, SAS tokens, Publisher ID)
├── .env.dev.user.example      # Template pour secrets (versionné)
└── generated/                  # Fichiers générés (NON versionnés)
    ├── config.env             # Format Bash (export VAR=val)
    ├── .env                   # Format dotenv (VAR=val)
    └── config.make            # Format Make (VAR := val)
```

### Variables types pour smw-marketplace

**`env/.env.dev` (publiques, versionnées)** :
```bash
# Azure
AZURE_LOCATION="canadacentral"
AZURE_RESOURCE_GROUP="rg-smw-marketplace-build"
VM_IMAGE_NAME="smw-marketplace-vm"
VM_SIZE="Standard_D4s_v3"

# SMW Stack
SMW_VERSION="6.0.1"
MEDIAWIKI_VERSION="1.43.0"
PHP_VERSION="8.2"
MYSQL_VERSION="8.0"
JAVA_VERSION="21"

# Extensions
#SMW_EXTENSIONS="SemanticMediaWiki,PluggableAuth,SimpleSAMLphp"

WIKI_PORT="443"
```

**`env/.env.dev.user` (secrets, NON versionnés)** :
```bash
# Azure Credentials (App Registration)
AZURE_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_CLIENT_SECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Azure Marketplace Publisher
AZURE_PUBLISHER_ID="mon-publisher-id"

# Build credentials
PACKER_SAS_TOKEN="sv=2024-..."
```

### Processus Bootstrap

1. **Séparation configuration/secrets** : Sources distinctes pour config publique et secrets privés
2. **Génération automatisée** : `make config` (via `bootstrap.py`) merge + génère 3 formats de sortie
3. **Validation intégrée** : Vérifie variables critiques avant de continuer
4. **Intégration Packer** : Variables disponibles sous forme de fichier HCL vars pour Packer
5. **Dépendance automatique** : `make packer-build` appelle automatiquement `make config`

```bash
# Génère aussi packer-vars.json depuis env/generated/
# Utilisable directement : packer build -var-file=env/generated/packer-vars.json vm-image.pkr.hcl
```

### Commandes principales

```bash
# Setup initial (inclut config)
make setup              # Installe dépendances + lance config

# Régénération manuelle
make config             # Génère env/generated/*

# Build (config est appelé automatiquement)
make packer-build       # Appelle config via packer-validate

# Utilisation dans scripts Bash
source env/generated/config.sh && packer build vm/packer/server-vm.pkr.hcl

# Utilisation dans Makefile
include env/generated/config.make
```

### ⚠️ Règles Critiques

1. **NE JAMAIS éditer** `env/generated/*` manuellement
2. **TOUJOURS** passer par `env/.env.dev` ou `env/.env.dev.user`
3. **TOUJOURS** régénérer avec `make config` après modification
4. **NE JAMAIS** commiter `env/generated/*` dans Git (dans .gitignore)
5. **NE JAMAIS** commiter `env/.env.dev.user` dans Git (contient secrets Azure)

## 📊 Matrice de Décision Quantifiée

| Critère | Poids | bootstrap.sh | Fichier .env unique | Variables système |
|---------|-------|--------------|---------------------|-------------------|
| **Sécurité** | 35% | 9/10 | 3/10 | 7/10 |
| **Maintenabilité** | 25% | 8/10 | 5/10 | 4/10 |
| **Simplicité setup** | 20% | 9/10 | 8/10 | 5/10 |
| **Multi-format (Packer/Make/Bash)** | 20% | 10/10 | 3/10 | 8/10 |
| **Score Total** | | **9.00** | **4.80** | **6.00** |

## ⚖️ Conséquences

### ✅ Positives

| Bénéfice | Impact | Métrique |
|----------|--------|----------|
| **Sécurité renforcée** | Critique | 0 secrets Azure exposés dans Git |
| **Builds Packer reproductibles** | Élevé | Variables disponibles automatiquement |
| **Setup simplifié** | Élevé | 1 commande (`make packer-build`) |
| **Onboarding rapide** | Moyen | ~10 min pour nouveau contributeur |

### ⚠️ Négatives & Mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Oubli régénération après modification | Moyenne | Faible | Dépendance auto `packer-build → config` |
| Secrets Azure exposés accidentellement | Faible | Critique | `.gitignore` strict + pre-commit hook |
| Variables manquantes avant build Packer | Faible | Moyen | Validation dans `bootstrap.py` |

## 🔄 Alternatives Considérées

### Alternative 1 : Azure Key Vault uniquement

**Avantages** : ✅ Gestion secrets enterprise, rotation automatique  
**Inconvénients** : ❌ Requiert authentification Azure pour développement local, overhead setup  
**Rejeté** : Trop lourd pour phase développement/build locale. Utiliser pour MediaWiki en production.

### Alternative 2 : Variables d'environnement système

**Avantages** : ✅ Pas de fichiers  
**Inconvénients** : ❌ Setup complexe multi-projets, pas de versionning config publique  
**Rejeté** : Maintenabilité insuffisante

## 🚀 Plan d'Implémentation

| Phase | Actions | Durée | Statut |
|-------|---------|-------|--------|
| **1. Structure** | Créer `env/` et fichiers templates | 30 min | ✅ Fait |
| **2. Bootstrap** | Développer `bootstrap.py` | 2h | ✅ Fait |
| **3. Packer** | Générer `generated.pkrvars.hcl` depuis config | 1h | ✅ Fait |
| **4. Makefile** | Intégrer `make config` avec dépendance auto | 30 min | ✅ Fait |
| **5. Documentation** | README env/ et instructions | 1h | ✅ Fait |

## 🎯 Critères de Succès

| Critère | Métrique | Cible |
|---------|----------|-------|
| **Sécurité** | Secrets dans Git | 0 |
| **Setup time** | Temps nouveau contributeur | < 15 min |
| **Builds Packer** | Succès sans config manuelle | 100% |
| **Formats supportés** | Bash + Make + Packer | ≥ 3 |

## 🔗 Traçabilité & Liens

### ADRs Connexes
- [ADR-601](./601-DEVOPS-nomenclature-scripts.md) - Nomenclature scripts
- [ADR-602](./602-DEVOPS-makefile-orchestrateur.md) - Makefile orchestrateur
- [ADR-200](./200-INFRA-azure-vm-image-packer.md) (à créer) - Image VM Azure Packer

### Fichiers Impactés
```
packer/
├── env/
│   ├── azure.env                   # Variables publiques SMW/Azure (SOURCE DE VÉRITÉ)
│   ├── azure.env.user              # Secrets (NON versionné)
│   ├── azure.env.user.example      # Template secrets (versionné)
│   └── generated/                  # Fichiers générés (NON versionnés)
│       ├── config.sh               # Format Bash
│       ├── .env                    # Format dotenv
│       ├── config.make             # Format Make
│       └── generated.pkrvars.hcl   # Variables Packer HCL
├── scripts/
│   └── bootstrap.py                # Script de génération
└── Makefile                        # Règle `make config`
```

## 📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-02-21 | @dev-team | Création ADR-600 | Adaptation depuis og-nore/ADR-600 pour smw-marketplace |
| 2026-04-13 | @dev-team | Renommage `bootstrap` → `config` | Meilleure clarté (pattern `./configure`), dépendance automatique |

**Évolutions futures possibles** :
- Intégration Azure Key Vault pour secrets en environnement CI/CD GitHub Actions
- Support multi-environnements Marketplace (`env.staging`, `env.prod`)
- Chiffrement secrets locaux avec `SOPS` ou `git-crypt`
