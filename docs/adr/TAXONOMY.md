# 🗂️ Taxonomie ADR - Guide de Classification

**Version**: 2.0  
**Date**: 2026-04-01  
**Projet**: nextcloud-marketplace  
**Basée sur**: Bonnes pratiques industrie (AWS, Azure, GitHub ADR Organization)

---

## ⚠️ Documents Complémentaires

**Ce document fait partie d'un système cohérent de 4 fichiers**:

1. **[ADR-000](./000-META-processus-creation-adr.md)** - Processus et numérotation
2. **[TAXONOMY.md](./TAXONOMY.md)** - Ce fichier (classification détaillée)
3. **[adr-template-ai-optimized.md](./adr-template-ai-optimized.md)** - Template pratique
4. **[README.md](./README.md)** - Index et vue d'ensemble

**⚡ IMPORTANT**: Toute modification de classification ici doit être reflétée dans le template et ADR-000.

---

## 📋 Vue d'Ensemble

Cette taxonomie permet de **classifier chaque ADR selon 7 dimensions** pour:
- ✅ Faciliter la recherche et le filtrage
- ✅ Permettre le parsing automatique par agents IA
- ✅ Construire des graphes de dépendances
- ✅ Générer des dashboards automatiques

**Format**: Frontmatter YAML dans chaque ADR (voir template)

---

## 🔍 Les 7 Dimensions de Classification

### 1️⃣ Lifecycle (Cycle de Vie)

**État actuel de l'ADR dans son cycle de vie**

| Valeur | Description | Emoji | Usage |
|--------|-------------|-------|-------|
| `draft` | Rédaction en cours, peut contenir TODOs | 🔄 | ADR incomplet |
| `proposed` | Prêt pour review équipe | 🔄 | En attente validation |
| `accepted` | Décision approuvée et en vigueur | ✅ | Implémenté |
| `rejected` | Proposition refusée (archivée) | ❌ | Non retenu |
| `deprecated` | Obsolète mais pas remplacé | ⚠️ | À retirer |
| `superseded` | Remplacé par nouvel ADR | ➡️ | Référencer nouveau |

**Exemple**:
```yaml
classification:
  lifecycle: "accepted"
```

---

### 2️⃣ Domain (Domaine Architectural)

**Domaine architectural principal concerné**

**Plages de numérotation réservées par domaine** :

| Préfixe | Plage | Domaine | Exemples ADR nextcloud-marketplace |
|---------|-------|---------|-------------------------------|
| `META` | 000-099 | Méta-processus | ADR-000: Processus ADR |
| `ARCH` | 100-199 | Architecture | ADR-100: Architecture Nextcloud VM Offer |
| `INFRA` | 200-299 | Infrastructure | ADR-200: Azure VM image build (Packer) |
| `SEC` | 300-399 | Sécurité | ADR-300: TLS + Network Security Groups |
| `DATA` | 400-499 | Données | ADR-400: Schéma MariaDB Nextcloud |
| `API` | 500-599 | API/Intégrations | ADR-500: Intégration Nextcloud API |
| `DEVOPS` | 600-699 | DevOps | ADR-600: Pipeline CI/CD provisioning |
| `TEST` | 700-799 | Tests & QA | ADR-700: Stratégie validation Marketplace |
| `BIZ` | 800-899 | Business | ADR-800: Modèle offre Azure Marketplace |
| `DOC` | 900-999 | Documentation | ADR-900: Documentation utilisateur VM |

**Descriptions par domaine** :

| Valeur | Description | Exemples contexte nextcloud-marketplace |
|--------|-------------|-------------------------------------|
| `architecture` | Décisions architecturales Nextcloud | Patterns intégration MariaDB + Nginx |
| `infrastructure` | Azure VM, Packer, Bicep, déploiement | Image VM, taille, région Azure |
| `security` | TLS, réseau, conformité Marketplace | NSG, TLS certificates, RBAC Azure |
| `data` | MariaDB, données Nextcloud | Choix versions MariaDB, fichiers Nextcloud |
| `api` | Interfaces Nextcloud API, intégrations | Nextcloud REST API, monitoring endpoints |
| `devops` | CI/CD, provisioning, automatisation | Scripts Packer, tests smoke |
| `test` | Tests, validation Marketplace | Certification VM, tests conformité |
| `business` | Offre Marketplace, licensing | Plan tarifaire, BYOL vs Pay-as-you-go |

**Exemple**:
```yaml
classification:
  domain: "infrastructure"
```

**Règle**: Choisir **UN seul domaine principal** (le plus impacté).

---

### 3️⃣ Impact (Niveau d'Impact)

**Ampleur de l'impact sur le système**

| Valeur | Description | Critères | Réversibilité Typique |
|--------|-------------|----------|----------------------|
| `low` | Impact local, facilement réversible | Single component, < 1 jour | Easy |
| `medium` | Plusieurs composants, effort modéré | Multi-component, 1-5 jours | Moderate |
| `high` | Système-wide, breaking change possible | Cross-system, > 1 semaine | Hard |
| `critical` | Fondamental, irréversible | Core architecture, migration coûteuse | Irreversible |

**Aide décision (contexte nextcloud-marketplace)**:
- **Low**: Changement version mineure PHP, ajout monitoring endpoint
- **Medium**: Changement configuration MariaDB, ajustement sizing VM
- **High**: Changement version MariaDB, base image OS VM
- **Critical**: Choix plateforme cloud, architecture Nextcloud core

---

### 4️⃣ Quality Attributes (Attributs Qualité - ASR)

**Qualités système affectées (basé sur ISO 25010)**

| Valeur | Description | Métriques Typiques | Pertinence nextcloud-marketplace |
|--------|-------------|-------------------|------------------------------|
| `performance` | Latence, débit, scalabilité | p95 latency, RPS | Temps chargement Nextcloud, requêtes API |
| `security` | Auth, autorisation, encryption | CVE count, TLS grade | TLS 1.2+, NSG rules, Marketplace compliance |
| `reliability` | Disponibilité, tolérance pannes | Uptime %, MTBF | Disponibilité VM client, restart Apache |
| `maintainability` | Modularité, testabilité | Test coverage | Scripts reproductibles, IaC |
| `cost` | Infrastructure, licensing | $/month Azure | Coût VM client, tarification offer |
| `usability` | Developer experience | Time to deploy | Déploiement simple pour l'organisation |
| `compliance` | Légal, réglementaire | Marketplace policies | Exigences Microsoft Marketplace, open source |
| `portability` | Multi-cloud, vendor independence | Migration effort | Portabilité image VM, multi-région Azure |

**Exemple**:
```yaml
classification:
  quality:
    - "security"
    - "reliability"
    - "compliance"
```

---

### 5️⃣ Reversibility (Facilité de Changement)

**Effort requis pour changer cette décision**

| Valeur | Effort | Durée Typique | Dépendances |
|--------|--------|---------------|-------------|
| `easy` | Très faible | < 1 jour | Aucune ou locale |
| `moderate` | Moyen | 1-5 jours | Quelques composants |
| `hard` | Élevé | > 1 semaine | Multiples systèmes |
| `irreversible` | Impossible/Prohibitif | Migration complète | Critique, données |

**Aide décision (contexte nextcloud-marketplace)**:
- **Easy**: Version PHP mineure, paramètre PHP-FPM
- **Moderate**: Version Nextcloud, configuration réseau VM
- **Hard**: Version MariaDB (migration données nécessaire)
- **Irreversible**: Image OS base (rebuild complet VM Marketplace)

---

### 6️⃣ Scope (Portée)

**Niveau stratégique de la décision**

| Valeur | Description | Horizon Temporel | Niveau |
|--------|-------------|------------------|--------|
| `strategic` | Vision long terme, organisation-wide | 3-5 ans | C-level, CTO |
| `tactical` | Implémentation spécifique, projet-wide | 6-18 mois | Team lead, Architect |
| `operational` | Choix techniques locaux, component-level | 1-6 mois | Developer |

**Aide décision (contexte nextcloud-marketplace)**:
- **Strategic**: Choix Azure Marketplace vs autre canal distribution, base de données principale
- **Tactical**: Architecture image VM, pipeline CI/CD, certification Marketplace
- **Operational**: Script provisioning, version package, configuration PHP-FPM

---

### 7️⃣ Tech Areas (Domaines Technologiques)

**Technologies/frameworks/plateformes concernés** (liste libre)

#### Languages & Runtimes
- `php`, `bash`, `python`

#### Cloud & Infrastructure
- `azure`, `azure-marketplace`, `vm`, `bicep`, `terraform`, `packer`

#### Nextcloud Stack
- `nextcloud`, `mariadb`, `nginx`, `php-fpm`, `redis`, `composer`

#### Data & Storage
- `mariadb`, `sql`, `database`, `rest-api`

#### Security & Networking
- `tls`, `ssl`, `nsg`, `azure-key-vault`, `nginx`

#### DevOps & CI/CD
- `github-actions`, `azure-devops`, `shell-script`, `packer`

#### Monitoring & Operations
- `azure-monitor`, `log-analytics`, `grafana`, `prometheus`

**Exemple**:
```yaml
classification:
  tech_areas:
    - "azure"
    - "vm"
    - "packer"
    - "nextcloud"
    - "mariadb"
```

---

## 📊 Exemple Complet

### ADR-200: Construction Image VM Azure avec Packer

```yaml
---
adr: 200
title: "Construction Image VM Azure avec Packer"
status: "proposed"
date: 2026-02-21

classification:
  lifecycle: "proposed"
  domain: "infrastructure"
  impact: "high"
  quality:
    - "reliability"
    - "maintainability"
    - "compliance"
  reversibility: "hard"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "vm"
    - "packer"
    - "nextcloud"
    - "php"
    - "mariadb"

tags: ["azure-marketplace", "vm", "packer", "image"]
stakeholders: ["@architecture-team", "@devops-team"]
---
```

---

## 🔎 Cas d'Usage

### Recherche par Domain
```bash
# Tous les ADRs infrastructure
grep -l 'domain: "infrastructure"' docs/adr/*.md
```

### Filtrage par Impact
```bash
# ADRs critiques seulement
grep -l 'impact: "critical"' docs/adr/*.md
```

### ADRs concernant la conformité Marketplace
```bash
grep -l '"compliance"' docs/adr/*.md
```

### Recherche par tech_area Nextcloud
```bash
grep -l '"nextcloud"' docs/adr/*.md
```

---

## ✅ Checklist Validation Classification

Avant d'accepter un ADR, vérifier:

- [ ] **Lifecycle**: État cohérent avec contenu ADR
- [ ] **Domain**: UN seul domaine principal choisi
- [ ] **Impact**: Niveau justifié dans section Conséquences
- [ ] **Quality**: ≥ 1 attribut qualité listé
- [ ] **Reversibility**: Cohérent avec impact et scope
- [ ] **Scope**: Aligné avec stakeholders et horizon
- [ ] **Tech Areas**: ≥ 1 technologie listée

---

## 🏷️ Convention Nommage Fichiers (Format Hybride)

### Format Standard

**Pattern** : `XXX-CATÉGORIE-titre-kebab-case.md`

### Exemples nextcloud-marketplace

```
000-META-processus-creation-adr.md          # META: 000-099
100-ARCH-nextcloud-vm-offer-architecture.md       # ARCH: 100-199
200-INFRA-azure-vm-image-packer.md          # INFRA: 200-299
300-SEC-tls-network-security-groups.md      # SEC: 300-399
400-DATA-mariadb-nextcloud-schema.md           # DATA: 400-499
500-API-nextcloud-api-integration.md        # API: 500-599
600-DEVOPS-packer-ci-pipeline.md            # DEVOPS: 600-699
700-TEST-marketplace-certification.md       # TEST: 700-799
800-BIZ-azure-marketplace-offer-model.md    # BIZ: 800-899
```

### Commandes Recherche par Catégorie

```bash
# ADRs infrastructure
ls -1 docs/adr/*-INFRA-*.md

# ADRs sécurité ET data
ls -1 docs/adr/*-{SEC,DATA}-*.md

# Comptage par catégorie
ls -1 docs/adr/*.md | grep -oE "[A-Z]+" | sort | uniq -c
```

---

## 📚 Références

### Standards Industrie
- **ISO 25010**: System and software quality models
- **Azure Well-Architected**: 5 pillars (reliability, security, performance, cost, operational excellence)
- **Microsoft Azure Marketplace**: [VM Offer Requirements](https://learn.microsoft.com/en-us/azure/marketplace/azure-vm-offer-setup)

### Bonnes Pratiques ADR
- [Joel Parker Henderson - ADR GitHub](https://github.com/joelparkerhenderson/architecture-decision-record)
- [ADR.github.io](https://adr.github.io/)
- [AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/architectural-decision-records/)

---

## 📝 Notes

**Évolution**: Cette taxonomie peut évoluer avec le projet. Si changement majeur, créer nouvel ADR et superseder ADR-000.

**Contexte spécifique nextcloud-marketplace**: La classification `compliance` est particulièrement importante dans ce projet en raison des exigences strictes de certification Microsoft Azure Marketplace et des obligations de licensing open source (Nextcloud est sous licence AGPL-3.0).

---

**Version**: 2.0  
**Maintenu par**: @architecture-team  
**Dernière mise à jour**: 2026-04-01  
**Projet**: nextcloud-marketplace
