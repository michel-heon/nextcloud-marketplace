---
adr: 604
title: "Modularisation Scripts et Élimination Duplication Fonctionnelle"
status: "accepted"
date: 2026-02-21
classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "medium"
  quality: ["maintainability", "reusability", "testability"]
  reversibility: "easy"
  scope: "tactical"
  tech_areas: ["bash", "scripting", "automation", "packer"]
tags: ["modularisation", "DRY", "code-reuse", "refactoring", "bash", "packer"]
stakeholders: ["@dev-team", "@devops-team"]
effort: "medium"
related_issues: []
related_adrs: [601, 602]
replaces: null
superseded_by: null
---

# ADR 604: Modularisation Scripts et Élimination Duplication Fonctionnelle

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-02-21 |
| **Impact** | 🟡 Moyen (maintenabilité scripts) |
| **Domaine** | DevOps |
| **Réversibilité** | 🟢 Facile (modules additionnels) |
| **Portée** | `scripts/` (extensible aux provisioners Packer) |

## 🎯 Contexte

### Situation Anticipée

Le projet smw-marketplace comprend des scripts Bash pour :
- **Provisioning MediaWiki** : `mediawiki-install.sh`, `mediawiki-configure.sh`
- **Composants** : `apache-install.sh`, `mysql-install.sh`, `smw-install.sh`
- **Sécurité** : `tls-configure.sh`, `firewall-configure.sh`, `security-harden.sh`
- **Validation** : `vm-smoke-test.sh`, `marketplace-validate.sh`, `tls-validate.sh`

### Problèmes identifiés sans modularisation

**Boilerplate répété dans chaque script** :
```bash
# Pattern répété dans chaque script (15-20 lignes) :
#!/usr/bin/env bash
set -euo pipefail

# Couleurs
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Logging
log_info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Chargement config
source env/generated/config.env 2>/dev/null || { log_error "Config manquante. Lancer make setup"; exit 1; }
```

**Fonctions dupliquées** potentielles :
- `check_command_exists()` dans smoke-test + validate = 2 copies
- `wait_for_service()` dans mediawiki-test + smw-test = 2 copies
- `check_azure_login()` dans chaque script Azure = N copies
- Gestion erreurs HTTP inconsistante entre scripts

**Conséquences** :
- Bug dans `wait_for_service()` → corriger plusieurs fichiers
- Ajout de retry logic → modifier chaque script individuellement
- Comportement inconsistant entre scripts similaires

## 💡 Décision

**Nous adoptons une architecture modulaire avec bibliothèques partagées dans `scripts/lib/` pour éliminer duplication et standardiser comportement.**

### Principes Directeurs

#### 1. DRY (Don't Repeat Yourself)
**Règle** : Code identique dans 2+ scripts = extraction en module obligatoire

**Seuils d'extraction** :
- Fonction identique dans 2+ scripts → `scripts/lib/` obligatoire
- Boilerplate > 10 lignes → module `lib/common.sh`
- Logique métier > 30 lignes identiques → module dédié

#### 2. Séparation Responsabilités

```
┌─────────────────────────────────────────────────┐
│  Scripts d'action (scripts/*.sh)                │  ← Logique spécifique
│  - Orchestration des étapes                     │
│  - Arguments et paramètres                      │
│  - Formatage sortie spécifique                  │
└─────────────────┬───────────────────────────────┘
                  │ source
┌─────────────────▼───────────────────────────────┐
│  Bibliothèques (scripts/lib/)                   │  ← Code réutilisable
│  - lib/common.sh     (logging, couleurs, setup) │
│  - lib/azure.sh      (Azure CLI helpers)        │
│  - lib/server.sh       (helpers MediaWiki/Apache)      │
│  - lib/network.sh    (wait_for_service, TLS)    │
└─────────────────────────────────────────────────┘
```

#### 3. Migration Progressive (Strangler Fig Pattern)

Créer les modules au fur et à mesure, refactoriser scripts existants progressivement. Pas de big-bang rewrite.

### Architecture de Solution

#### `scripts/lib/common.sh`

**Responsabilité** : Utilitaires communs à tous les scripts

```bash
#!/usr/bin/env bash
# lib/common.sh — Utilitaires communs smw-marketplace
# Source ce fichier: source "$(dirname "$0")/lib/common.sh"

# Couleurs
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

# Logging standardisé
log_info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "\n${BLUE}${BOLD}=== $* ===${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }

# Chargement configuration (avec validation)
load_config() {
    local config_file="${1:-env/generated/config.env}"
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration manquante: $config_file"
        log_error "Exécuter: make setup"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$config_file"
    log_info "Configuration chargée depuis $config_file"
}

# Vérification commande disponible
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Commande requise non trouvée: $cmd"
        exit 1
    fi
}

# Vérifier plusieurs commandes
check_required_commands() {
    for cmd in "$@"; do
        check_command "$cmd"
    done
    log_success "Toutes les dépendances présentes: $*"
}

# Attendre qu'un service soit disponible (HTTP)
wait_for_service() {
    local url="$1"
    local max_attempts="${2:-30}"
    local wait_seconds="${3:-5}"
    local attempt=1

    log_info "Attente service: $url (max ${max_attempts} tentatives)"
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sf --max-time 5 "$url" &>/dev/null; then
            log_success "Service disponible: $url"
            return 0
        fi
        log_info "Tentative $attempt/$max_attempts - Service pas encore disponible..."
        sleep "$wait_seconds"
        ((attempt++))
    done

    log_error "Service non disponible après $max_attempts tentatives: $url"
    return 1
}

# Exécuter avec retry
retry() {
    local max_attempts="$1"; shift
    local cmd=("$@")
    local attempt=1

    until "${cmd[@]}"; do
        if [[ $attempt -ge $max_attempts ]]; then
            log_error "Échec après $max_attempts tentatives: ${cmd[*]}"
            return 1
        fi
        log_warn "Tentative $attempt échouée, retry dans 5s..."
        ((attempt++))
        sleep 5
    done
}
```

---

#### `scripts/lib/azure.sh`

**Responsabilité** : Helpers Azure CLI pour smw-marketplace

```bash
#!/usr/bin/env bash
# lib/azure.sh — Helpers Azure CLI

# Vérifier connexion Azure CLI
check_azure_login() {
    if ! az account show &>/dev/null; then
        log_error "Non connecté à Azure. Exécuter: az login"
        exit 1
    fi
    local sub_name
    sub_name=$(az account show --query name -o tsv)
    log_info "Connecté Azure: $sub_name"
}

# Vérifier existence Resource Group
check_resource_group() {
    local rg="${1:-$AZURE_RESOURCE_GROUP}"
    if ! az group show --name "$rg" &>/dev/null; then
        log_error "Resource Group non trouvé: $rg"
        exit 1
    fi
    log_success "Resource Group OK: $rg"
}

# Créer Resource Group si absent
ensure_resource_group() {
    local rg="${1:-$AZURE_RESOURCE_GROUP}"
    local location="${2:-$AZURE_LOCATION}"
    if ! az group show --name "$rg" &>/dev/null; then
        log_info "Création Resource Group: $rg ($location)"
        az group create --name "$rg" --location "$location" --output none
        log_success "Resource Group créé: $rg"
    else
        log_info "Resource Group existant: $rg"
    fi
}

# Obtenir dernière version d'une image VM dans Gallery
get_latest_image_version() {
    local gallery="$1"
    local image_name="$2"
    local rg="${3:-$AZURE_RESOURCE_GROUP}"
    az sig image-version list \
        --resource-group "$rg" \
        --gallery-name "$gallery" \
        --gallery-image-definition "$image_name" \
        --query "[-1].name" -o tsv 2>/dev/null
}
```

---

#### `scripts/lib/server.sh`

**Responsabilité** : Helpers spécifiques MediaWiki/Apache/MySQL

```bash
#!/usr/bin/env bash
# lib/server.sh — Helpers spécifiques stack SMW

# Vérifier que MediaWiki répond (endpoint HTTP)
check_mediawiki_health() {
    local vivo_url="${1:-http://localhost:${MEDIAWIKI_PORT:-80}/server}"
    wait_for_service "$vivo_url" 30 10
}

# Vérifier API MediaWiki
check_mediawiki_api() {
    local mediawiki_api_url="${1:-http://localhost:${MEDIAWIKI_PORT:-80}/api.php}"
    local test_query='SELECT (COUNT(*) AS ?count) WHERE { ?s ?p ?o }'
    if curl -sf --data "query=$(python3 -c "import urllib.parse; print(urllib.parse.quote(\"$test_query\"))")" \
            "$mediawiki_api_url" &>/dev/null; then
        log_success "API MediaWiki opérationnel: $mediawiki_api_url"
        return 0
    else
        log_error "API MediaWiki non disponible: $mediawiki_api_url"
        return 1
    fi
}

# Vérifier que Apache est actif
check_apache_status() {
    local apache_port="${1:-${MEDIAWIKI_PORT:-80}}"
    if curl -sf "http://localhost:$apache_port" &>/dev/null; then
        log_success "Apache actif sur port $apache_port"
        return 0
    else
        log_error "Apache non accessible sur port $apache_port"
        return 1
    fi
}

# Vérifier que MySQL est actif
check_mysql_status() {
    local mysql_port="${1:-3306}"
    if curl -sf "http://localhost:$mysql_port/" &>/dev/null; then
        log_success "MySQL actif sur port $mysql_port"
        return 0
    else
        log_error "MySQL non accessible sur port $mysql_port"
        return 1
    fi
}
```

---

### Pattern Standard d'un Script

```bash
#!/usr/bin/env bash
# scripts/vm-smoke-test.sh
# Tests smoke post-déploiement VM SMW
# Usage: ./scripts/vm-smoke-test.sh [--mediawiki-url http://...] [--verbose]

set -euo pipefail

# Chargement bibliothèques partagées
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/server.sh"
source "${SCRIPT_DIR}/lib/azure.sh"

# Variables avec valeurs par défaut
MEDIAWIKI_URL="${MEDIAWIKI_URL:-http://localhost:${MEDIAWIKI_PORT:-80}/server}"
VERBOSE="${VERBOSE:-false}"

# Chargement configuration
load_config

log_section "Smoke Tests VM MediaWiki"

# Vérifications requises
check_required_commands curl az

# Tests
log_info "Test 1: Apache accessible"
check_apache_status

log_info "Test 2: MediaWiki répond"
check_mediawiki_health "$MEDIAWIKI_URL"

log_info "Test 3: API MediaWiki"
check_mediawiki_api

log_info "Test 4: MySQL accessible"
check_mysql_status

log_success "Tous les smoke tests passés ✅"
```

### Organisation dans `scripts/`

```
scripts/
├── README.md                      # Documentation + liste scripts
├── lib/                           # Bibliothèques partagées
│   ├── common.sh                  # Logging, config, retry, wait_for_service
│   ├── azure.sh                   # Helpers Azure CLI
│   ├── server.sh                    # Helpers MediaWiki/Apache/MySQL
│   └── network.sh                 # Helpers TLS, HTTP checks
│
├── vm-provision.sh                # Provisioning complet (appelle autres scripts)
├── vm-smoke-test.sh               # Smoke tests
├── vm-validate.sh                 # Validation image
│
├── mediawiki-install.sh                # Installation MediaWiki
├── mediawiki-configure.sh              # Configuration MediaWiki
├── apache-install.sh              # Installation Apache
├── apache-configure.sh            # Configuration Apache
├── mysql-install.sh                # Installation MySQL
├── smw-install.sh         # Installation smw-extensions
│
├── tls-configure.sh               # Configuration TLS
├── tls-validate.sh                # Validation TLS
├── firewall-configure.sh          # Règles firewall
├── security-harden.sh             # Hardening OS
│
├── azure-login.sh                 # Authentification Azure
├── image-build.sh                 # Build Packer
├── marketplace-validate.sh        # Validation Marketplace
└── marketplace-publish.sh         # Publication Marketplace
```

### Checklist avant de créer un script

- [ ] La fonctionnalité existe-t-elle déjà dans `lib/` ?
- [ ] Existe-t-il un script similaire dans `scripts/` ?
- [ ] Puis-je paramétrer un script existant ?
- [ ] Si logique métier commune → extraire dans `lib/`
- [ ] Le script source les modules nécessaires de `lib/`

## ⚖️ Conséquences

### ✅ Positives

| Bénéfice | Description |
|----------|-------------|
| **DRY** | Bug dans `wait_for_service` → corriger une seule fois dans `lib/common.sh` |
| **Cohérence** | Même format de logs et couleurs dans tous les scripts |
| **Testabilité** | Modules `lib/` testables indépendamment |
| **Lisibilité** | Scripts courts (logique déléguée aux modules) |

### ⚠️ Négatives & Mitigations

| Risque | Mitigation |
|--------|------------|
| Casser scripts Packer (pas de `lib/` dans la VM) | Scripts Packer auto-contenus ou copier `lib/` via provisioner |
| Overhead organisation | Structure simple, un seul niveau `lib/` |

## 🔗 Traçabilité & Liens

- [ADR-601](./601-DEVOPS-nomenclature-scripts.md) - Nomenclature scripts
- [ADR-602](./602-DEVOPS-makefile-orchestrateur.md) - Makefile orchestrateur

## 📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-02-21 | @dev-team | Création ADR-604 | Adaptation depuis og-nore/ADR-610 pour smw-marketplace |

**Note Packer** : Les provisioners Packer Shell dans une VM ne peuvent pas `source` des fichiers de `lib/` relatifs au dépôt. Pour les scripts de provisioning Packer, deux approches :
1. Copier `scripts/lib/` via provisioner `file` avant les scripts Shell
2. Rendre les scripts Packer auto-contenus (pas de dépendance lib) — préféré pour clarté
