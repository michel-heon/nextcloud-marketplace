# 📚 Architecture Decision Records (ADR) — smw-marketplace

**Index central** de toutes les décisions architecturales du projet **smw-marketplace**.

> Le projet vise à industrialiser et publier sur **Microsoft Azure Marketplace** une offre VM intégrant la solution open source **Semantic MediaWiki** (SMW) sur Azure, avec MediaWiki, PHP, Apache et MySQL, destinée aux organisations souhaitant déployer un wiki sémantique enterprise sur leur abonnement Azure.

---

## 🗂️ Documents du Système ADR

| Document | Description |
|----------|-------------|
| **[ADR-000](./000-META-processus-creation-adr.md)** | Processus et règles de création des ADRs |
| **[TAXONOMY.md](./TAXONOMY.md)** | Classification détaillée (7 dimensions) |
| **[adr-template-ai-optimized.md](./adr-template-ai-optimized.md)** | Template à copier pour un nouvel ADR |
| **[README.md](./README.md)** | Ce fichier (index et guide rapide) |

---

## ⚡ Créer un Nouvel ADR Rapidement

```bash
# 1. Identifier la plage de catégorie (voir tableau Numérotation)
# 2. Trouver le prochain numéro disponible dans la plage
ls -1 docs/adr/2*.md | tail -1   # Exemple: bloc INFRA (200-299)

# 3. Créer le fichier depuis le template
cp docs/adr/adr-template-ai-optimized.md docs/adr/201-INFRA-nouvelle-decision.md

# 4. Rédiger, committer et mettre à jour ce README
git add docs/adr/201-INFRA-nouvelle-decision.md docs/adr/README.md
git commit -m "docs(adr): ADR-201 [INFRA] Nouvelle décision"
```

---

## 📋 Index des ADRs par Catégorie

### 🔧 META — Méta-processus (000-099)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| [000](./000-META-processus-creation-adr.md) | Processus de Création et Gestion des ADR | ✅ Accepté | 2026-02-21 | Gouvernance |
| [001](./001-META-definition-projet-smw-marketplace.md) | Définition et Cadrage du Projet smw-marketplace | ✅ Accepté | 2026-04-01 | Gouvernance |
| [002](./002-META-agent-ia-non-hallucination.md) | Agent IA — Contrainte de Non-Hallucination et Usage Vérifié | ✅ Accepté | 2026-05-09 | Gouvernance |

---

### 🏗️ ARCH — Architecture (100-199)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| *(aucun ADR pour l'instant)* | | | | |

---

### ☁️ INFRA — Infrastructure Azure (200-299)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| [200](./200-INFRA-azure-infrastructure-vm-offer.md) | Infrastructure Azure — VM Offer : Compute Gallery, NSG, ARM Template, Data Disk | ✅ Accepté | 2026-04-01 | Infrastructure |

---

### 🔒 SEC — Sécurité (300-399)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| [300](./300-SEC-securite-hardening-vm-certification.md) | Sécurité VM — Hardening OS Ubuntu pour Certification Azure Marketplace | ✅ Accepté | 2026-02-22 | Sécurité |
| [302](./302-SEC-sso-microsoft-entra-id.md) | Authentification SSO via Microsoft Entra ID | ✅ Accepté | 2025-07-12 | Sécurité |
| [303](./303-SEC-rbac-permissions-partner-center-gallery.md) | Permissions RBAC Azure Compute Gallery pour Partner Center — Visibilité Images VM | ✅ Accepté | 2026-05-19 | Sécurité |

---

### 🗄️ DATA — Données & Semantic Web (400-499)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| *(aucun ADR pour l'instant)* | | | | |

---

### 🔌 API — Intégrations & APIs (500-599)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| *(aucun ADR pour l'instant)* | | | | |

---

### ⚙️ DEVOPS — DevOps & CI/CD (600-699)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| [600](./600-DEVOPS-bootstrap-configuration-management.md) | Bootstrap et Gestion de la Configuration | ✅ Accepté | 2026-02-21 | DevOps |
| [601](./601-DEVOPS-nomenclature-scripts.md) | Nomenclature et Organisation des Scripts | ✅ Accepté | 2026-02-21 | DevOps |
| [602](./602-DEVOPS-makefile-orchestrateur.md) | Makefile comme Orchestrateur Standard | ✅ Accepté | 2026-02-21 | DevOps |
| [603](./603-DEVOPS-git-workflow-et-strategie-versioning.md) | Git Workflow et Stratégie de Versioning | ✅ Accepté | 2026-02-21 | DevOps |
| [604](./604-DEVOPS-modularisation-scripts-partages.md) | Modularisation Scripts et Élimination Duplication | ✅ Accepté | 2026-02-21 | DevOps |
| [607](./607-DEVOPS-procedure-version-bump.md) | Procédure de Bumping de Version — Image VM et Fichiers de Configuration | ✅ Accepté | 2026-03-07 | DevOps |
| [608](./608-DEVOPS-non-duplication-fonctionnelle-transversale.md) | Non-Duplication Fonctionnelle Transversale — Bash, Python, PHP | ✅ Accepté | 2026-04-01 | DevOps |
| [609](./609-DEVOPS-php-version-strategy.md) | Stratégie Version PHP pour Semantic MediaWiki | ✅ Accepté | 2026-04-04 | DevOps |
| [611](./611-DEVOPS-gestion-couleurs-scripts-make.md) | Gestion des Couleurs dans les Scripts Make | ✅ Accepté | 2026-04-08 | DevOps |
| [613](./613-DEVOPS-provisioner-architecture-validation.md) | Architecture et Validation des Provisioners Packer | ✅ Accepté | 2026-04-16 | DevOps |
| [614](./614-DEVOPS-dev-vm-iteration-workflow.md) | Workflow de Développement VM Rapide | ✅ Accepté | 2026-04-16 | DevOps |
| [616](./616-DEVOPS-blob-storage-cache-packages-packer.md) | Blob Storage Azure comme Cache de Packages pour les Builds Packer | ✅ Accepté | 2026-05-08 | DevOps |
| [617](./617-DEVOPS-packer-outil-construction-images-vm.md) | HashiCorp Packer — Outil de Construction d'Images VM Azure | ✅ Accepté | 2026-05-09 | DevOps |
| [618](./618-DEVOPS-strategie-debug-post-image-vm.md) | Stratégie de Débogage Post-Image : Cycle Observation VM → Correction Provisioner | ✅ Accepté | 2026-05-15 | DevOps |

---

### 🧪 TEST — Tests & Validation (700-799)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| [700](./700-TEST-plan-tests-integration.md) | Plan de Tests d'Intégration — SMW Marketplace | ✅ Accepté | 2026-05-12 | Test |
| [701](./701-TEST-protocole-qualification-post-image-vm.md) | Protocole de Qualification Post-Image : Critères d'Acceptation et Non-Régression | ✅ Accepté | 2026-05-15 | Test |


---

### 💼 BIZ — Business & Marketplace (800-899)

| ADR | Titre | Statut | Date | Domaine |
|-----|-------|--------|------|---------|
| [800](./800-BIZ-publication-azure-marketplace-vm-offer.md) | Publication Offre VM sur Azure Marketplace — Conformité et Bonnes Pratiques Microsoft | ✅ Accepté | 2026-02-21 | BIZ |
| [801](./801-BIZ-strategie-documentation-marketplace.md) | Stratégie de Documentation — Offre Azure Marketplace (utilisateur final) | ✅ Accepté | 2026-03-05 | BIZ |

---

## 📊 Statistiques

| Indicateur | Valeur |
|-----------|--------|
| **Total ADRs** | 22 |
| **Acceptés** | 22 |
| **Dépréciés** | 0 |
| **Proposés** | 0 |
| **Brouillons** | 0 |
| **Par Domaine** | META: 3, INFRA: 1, SEC: 3, DEVOPS: 13, BIZ: 2 |

---

## 🔍 Numérotation par Catégorie

| Préfixe | Plage | Domaine | Prochains disponibles |
|---------|-------|---------|----------------------|
| `META` | 000-099 | Méta-processus | 003 |
| `ARCH` | 100-199 | Architecture SMW/MediaWiki | 100 |
| `INFRA` | 200-299 | Azure VM, Packer, IaC | 201 |
| `SEC` | 300-399 | TLS, NSG, conformité Marketplace | 304 |
| `DATA` | 400-499 | Données sémantiques, propriétés SMW, ontologies | 400 |
| `API` | 500-599 | API MediaWiki, intégrations | 500 |
| `DEVOPS` | 600-699 | CI/CD, scripts provisioning | 618 |
| `TEST` | 700-799 | Validation Marketplace, smoke tests | 701 |
| `BIZ` | 800-899 | Offre Marketplace, licensing | 802 |

---

## 🏷️ Statuts

| Emoji | Statut | Description |
|-------|--------|-------------|
| 🔄 | Brouillon / Proposé | En cours de rédaction ou en attente de validation |
| ✅ | Accepté | Décision approuvée et implémentée |
| ❌ | Rejeté | Proposition refusée (archivée pour référence) |
| ⚠️ | Déprécié | Obsolète, non remplacé |
| ➡️ | Supersédé | Remplacé par un ADR plus récent |

---

## 🔗 Ressources Projet

- [MediaWiki.org](https://www.mediawiki.org/)
- [Semantic MediaWiki](https://www.semantic-mediawiki.org/)
- [SMW GitHub](https://github.com/SemanticMediaWiki/SemanticMediaWiki)
- [Azure Marketplace VM Offer](https://learn.microsoft.com/en-us/azure/marketplace/azure-vm-offer-setup)
- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/)

---

_Mise à jour : 2026-03-11_
