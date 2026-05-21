---
adr: 603
title: "Git Workflow et Stratégie de Versioning"
status: "accepted"
date: 2026-02-21
classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "high"
  quality: ["maintainability", "traceability", "collaboration"]
  reversibility: "moderate"
  scope: "strategic"
  tech_areas: ["git", "version-control", "devops", "workflow", "release-management"]
tags: ["devops", "git", "workflow", "versioning", "collaboration", "azure-marketplace"]
stakeholders: ["@devops-team", "@dev-team", "@architecture-team"]
effort: "medium"
related_issues: []
related_adrs: [601, 602]
replaces: null
superseded_by: null
---

# ADR 603: Git Workflow et Stratégie de Versioning

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-02-21 |
| **Impact** | 🔴 Élevé (processus collaboration) |
| **Domaine** | DevOps |
| **Réversibilité** | 🟡 Moyenne |
| **Portée** | Projet complet |

## 🎯 Contexte

Le projet smw-marketplace nécessite une stratégie Git claire pour :
- **Gérer les contributions** en parallèle (provisioning, VM image, docs, tests)
- **Séparer clairement** les phases de développement et les releases stables
- **Tracer les versions** des images VM publiées sur Azure Marketplace
- **Permettre des rollbacks** rapides en cas de régression image VM
- **Coordonner** les différents domaines du projet : infrastructure Packer, scripts SMW, documentation ADR, tests Marketplace

## Décision

### 1. Structure des branches (GitHub Flow adapté)

Nous adoptons **GitHub Flow** avec préfixes utilisateur obligatoires :

```
main (production stable)
  ↑
utilisateur/feature-name (développement)
  ↑
hotfix/correction (urgences uniquement)
```

#### **Branche `main`**
- **Rôle** : Code et images stables, prêts pour Azure Marketplace
- **Protection** :
  - Merges uniquement via Pull Request
  - Minimum 1 review requis
  - Status checks CI doivent passer
  - Direct pushes interdits
- **Tags** : Versions stables des releases VM (ex: `v1.0.0-smw-initial`)

#### **Branches personnelles `utilisateur/feature-name`**

**Décision clé** : Préfixe utilisateur obligatoire (au lieu de `feature/nom`)

```bash
# ✅ Formats corrects
michel-heon/packer-smw-base-image
michel-heon/tls-configuration
jane-doe/smw-extensions-support
john-smith/marketplace-certification

# ❌ Formats à éviter
feature/packer-image       # Pas de préfixe utilisateur
SMW-16-extension        # Format ticket dans branche
```

**Avantages** :
- Isolation complète par contributeur
- Traçabilité instantanée (`git branch -r` montre qui travaille sur quoi)
- Zéro conflit de noms entre contributeurs

**Cycle de vie** : Créées depuis `main`, mergées dans `main`, supprimées après merge.

### 2. Convention de versioning (SemVer adapté)

Nous adoptons **Semantic Versioning 2.0.0** avec suffixes descriptifs obligatoires :

```
v{MAJOR}.{MINOR}.{PATCH}-{description-kebab-case}
```

#### **Numérotation sémantique**

- **MAJOR** : Changements incompatibles ou refonte majeure
  - Exemples : Changement OS base image, migration PHP, changement stack
- **MINOR** : Nouvelles fonctionnalités compatibles
  - Exemples : Ajout monitoring, nouvelle configuration TLS, support nouvelle extension SMW
- **PATCH** : Corrections de bugs
  - Exemples : Hotfix script provisioning, correction timeout Apache

#### **Suffixes par phase**

| Phase | Format | Exemple | Usage |
|-------|--------|---------|-------|
| Développement actif | `-alpha.{n}-{mot-clé}` | `v1.1.0-alpha.1-smw-install` | Branche personnelle |
| Tests internes | `-beta.{n}-{mot-clé}` | `v1.1.0-beta.1-smw-install` | Branche personnelle, feature complète |
| Release candidate | `-rc{n}-{mot-clé}` | `v1.1.0-rc1-smw-install` | Avant merge main |
| Production (main) | `-{description}` | `v1.1.0-vivo-tls-support` | Tag sur main après merge |

#### **Règle stricte : Description OBLIGATOIRE pour tous les tags**

✅ **Formats obligatoires** :
```bash
# Branches personnelles
v1.0.0-alpha.1-packer-base-image
v1.1.0-beta.2-smw-semantic
v1.2.0-rc1-tls-configuration

# Branche main (production)
v1.0.0-initial-smw-vm
v1.1.0-tls-hardening
v2.0.0-ubuntu-24-migration
```

❌ **Formats non conformes** :
```bash
v1.0.0               # Manque description obligatoire
v1.1.0-alpha.1       # Manque mot-clé descriptif
v2.0.0-test          # Trop générique
```

#### **Exemples conformes pour smw-marketplace**

*Branches personnelles* :
- `v1.0.0-alpha.1-packer-base-image` — Build Packer initial
- `v1.0.0-alpha.2-smw-install` — Installation MediaWiki/SMW scripts
- `v1.0.0-beta.1-tls-configure` — Configuration TLS
- `v1.1.0-alpha.1-smw-extension` — Support extensions SMW

*Branche main (releases)* :
- `v1.0.0-initial-smw-vm` — Première image VM SMW complète
- `v1.1.0-tls-hardening` — Amélioration sécurité TLS
- `v1.2.0-monitoring-azure` — Ajout Azure Monitor
- `v2.0.0-ubuntu-24-migration` — Migration Ubuntu 24.04

#### **Conventions de nomenclature des descriptions**

| Type de changement | Format recommandé | Exemples |
|---------------------|-------------------|----------|
| Version initiale | `initial-{composant}` | `v1.0.0-initial-smw-vm` |
| Composant SMW | `vivo-{fonctionnalité}` | `v1.1.0-smw-sparql-endpoint` |
| Sécurité | `{composant}-hardening`, `tls-{action}` | `v1.2.0-tls-hardening` |
| Infrastructure | `{cloud}-{action}` | `v1.3.0-azure-monitor` |
| Correction | `{composant}-{problème}-fix` | `v1.1.1-apache-timeout-fix` |
| OS/Plateforme | `{os}-{version}-migration` | `v2.0.0-ubuntu-24-migration` |
| Marketplace | `marketplace-{action}` | `v1.4.0-marketplace-certified` |

### 3. Workflow de développement

#### **Cycle de vie d'une feature**

```bash
# 1. Créer branche personnelle depuis main à jour
git checkout main
git pull origin main
git checkout -b michel-heon/packer-smw-base-image

# 2. Développement avec tags alpha descriptifs
git commit -m "feat(packer): ajout template Packer Ubuntu 22.04"
git tag -a v1.0.0-alpha.1-packer-base-image -m "Alpha: template Packer initial Ubuntu 22.04 + SMW"
git push origin michel-heon/packer-smw-base-image --tags

# 3. Itérations
git commit -m "feat(packer): ajout provisioner installation Apache + MediaWiki"
git tag -a v1.0.0-alpha.2-packer-base-image -m "Alpha: provisioners Apache + MediaWiki ajoutés"
git push --tags

# 4. Tests internes → tag beta
git tag -a v1.0.0-beta.1-packer-base-image -m "Beta: image buildée et MediaWiki accessible"
git push --tags

# 5. Pull Request vers main
gh pr create --base main --head michel-heon/packer-smw-base-image \
  --title "feat(vm): Image VM SMW base (Packer + Ubuntu 22.04)" \
  --body "Première image VM SMW complète:
  - Template Packer Ubuntu 22.04 LTS
  - Installation SMW 6.0.1 / Citro + MySQL
  - Installation Apache 2.4 + PHP-FPM
  - Configuration MySQL
  - Hardening sécurité de base"

# 6. Après merge, tag de release sur main
git checkout main && git pull origin main
git tag -a v1.0.0-initial-smw-vm -m "Release v1.0.0: Première image VM SMW complète

- SMW 6.0.1 + MediaWiki/SMW sur Ubuntu 22.04 LTS
- Apache 2.4 + PHP 8.2
- MySQL + SMW
- Hardening sécurité de base

Prêt pour certification Azure Marketplace."
git push origin main --tags
```

#### **Hotfix en production**

```bash
# 1. Créer depuis main
git checkout main && git pull origin main
git checkout -b hotfix/apache-timeout-fix

# 2. Fix et tag
git commit -m "fix(apache): augmenter connection timeout de 30s à 60s"
git tag -a v1.0.1-alpha.1-apache-timeout-fix -m "Hotfix: timeout Apache"
git push origin hotfix/apache-timeout-fix --tags

# 3. PR express
gh pr create --base main --head hotfix/apache-timeout-fix \
  --title "hotfix: Correction timeout connexion Apache" \
  --body "Augmentation timeout Apache connection 30s → 60s"

# 4. Tag sur main après merge
git checkout main && git pull origin main
git tag -a v1.0.1-apache-timeout-fix -m "Hotfix v1.0.1: Correction timeout Apache"
git push origin main --tags
```

### 4. Protection des branches

#### **Règles GitHub pour `main`**
```yaml
# Protection main
required_reviews: 1
require_status_checks: true    # CI Packer validate doit passer
enforce_admins: true
allow_force_pushes: false
allow_deletions: false
delete_branch_on_merge: true
```

### 5. Messages de commit (Conventional Commits)

```
<type>(<scope>): <description>

[corps optionnel]
```

#### **Types**
- `feat` : Nouvelle fonctionnalité (script, provisioner, config)
- `fix` : Correction de bug
- `docs` : Documentation (ADR, README)
- `refactor` : Refactoring scripts sans changement fonctionnel
- `test` : Ajout ou correction de tests
- `chore` : Maintenance, versions dépendances
- `ci` : Configuration CI/CD GitHub Actions
- `build` : Build Packer, Makefile

#### **Scopes smw-marketplace**
- `packer` : Template Packer, builds image VM
- `vivo` : Installation/configuration MediaWiki/SMW
- `apache` : Apache server
- `mysql` : smw-mysql
- `smw` : Extensions SMW et MediaWiki
- `tls` : Certificats TLS, HTTPS
- `security` : Hardening, NSG, firewall
- `azure` : Infrastructure Azure, RG, images
- `marketplace` : Certification et publication Marketplace
- `adr` : Architecture Decision Records
- `docs` : Documentation générale

#### **Exemples conformes**

```bash
git commit -m "feat(packer): template SMW Ubuntu 22.04 LTS initial"

git commit -m "feat(tls): configuration TLS automatique avec Let's Encrypt ou cert auto-signé"

git commit -m "fix(apache): correction timeout connexion MySQL

- Augmentation timeout 30s → 60s
- Ajout retry logic exponential backoff pour SPARQL endpoint"

git commit -m "docs(adr): ADR-603 workflow Git et versioning smw-marketplace"

git commit -m "chore(packer): mise à jour SMW 6.0.1 → 1.13.2"

git commit -m "ci: ajout workflow GitHub Actions packer validate sur PR"

git commit -m "test(marketplace): ajout smoke tests certification Azure VM"
```

### 6. Structure de versioning image VM Marketplace

Les versions des images VM publiées sur Azure Marketplace suivent un format distinct :

```
{MAJOR}.{MINOR}.{PATCH}
```

**Correspondance** :
- Tag Git `v1.0.0-initial-smw-vm` → Image Marketplace version `1.0.0`
- Tag Git `v1.1.0-tls-hardening` → Image Marketplace version `1.1.0`
- Tag Git `v1.0.1-apache-timeout-fix` → Image Marketplace version `1.0.1`

La version Marketplace (sans `-description`) est dérivée du tag Git dans le pipeline CI/CD.

### 7. Directive — Alignement tag Git et IMAGE_VERSION (depuis 2026-03-04)

**Décision** : À partir du 2026-03-04, le numéro de version du tag Git **doit être identique** à `IMAGE_VERSION` défini dans `env/.env.dev`.

**Règle** :
```
env/.env.dev → IMAGE_VERSION="X.Y.Z"
       ↓
git tag → vX.Y.Z-{description}
```

**Workflow obligatoire lors d'un bump de version** :
```bash
# 1. Bumper IMAGE_VERSION dans env/.env.dev
sed -i 's/IMAGE_VERSION=.*/IMAGE_VERSION="X.Y.Z"/' env/.env.dev

# 2. Régénérer la configuration
make setup

# 3. Committer
git add env/.env.dev
git commit -m "chore: bump version to X.Y.Z"
git push

# 4. Créer le tag avec le même numéro de version
git tag -a vX.Y.Z-{description} -m "vX.Y.Z: {résumé des changements}"
git push origin --tags

# 5. Builder l'image
make packer-build
```

**Exemples conformes** :
```bash
# IMAGE_VERSION="1.0.8" → tag obligatoire : v1.0.8-*
git tag -a v1.0.8-permissions-775-fix -m "v1.0.8: fix permissions 775 /data/server/home+tdb2"

# IMAGE_VERSION="1.0.9" → tag obligatoire : v1.0.9-*
git tag -a v1.0.9-permissions-layout -m "v1.0.9: fix permissions layout /data complet"
```

❌ **Non conformes** :
```bash
git tag v1.0.9-fix      # IMAGE_VERSION doit être 1.0.9 dans .env.dev
git tag v0.9.1-truc     # Numéro découplé de IMAGE_VERSION
```

**Avantages** :
- Traçabilité parfaite : chaque image Packer ↔ un tag Git unique
- `IMAGE_VERSION` dans la Compute Gallery est toujours identifiable via `git tag`
- Élimination de la dualité version Git / version Marketplace

## ⚖️ Conséquences

### ✅ Positives

| Bénéfice | Description |
|----------|-------------|
| **Traçabilité releases** | Chaque image VM Marketplace correspond à un tag Git précis |
| **Tags auto-documentés** | Descriptions obligatoires → historique lisible |
| **Isolation contributeurs** | Branches par utilisateur, zéro conflit |
| **CI/CD clair** | Builds déclenchés sur PR + tags `v*` |

### ⚠️ Négatives & Mitigations

| Risque | Mitigation |
|--------|------------|
| Oubli description tag | CI check → rejeter tags sans `-description` |
| Prolifération branches | `delete_branch_on_merge: true` GitHub |
| Confusion version Git vs version Marketplace | Documenté ici + dans README |

## 🔄 Alternatives Considérées

### Git Flow (develop + release branches)
**Rejeté** : Trop complexe pour ce projet. Pas de releases fixes, déploiement sur demande.

### Trunk-based development (sans branches features)
**Rejeté** : Risque trop élevé sur `main` sans review pour images qui seront certifiées Marketplace.

## 🔗 Traçabilité & Liens

- [ADR-601](./601-DEVOPS-nomenclature-scripts.md) - Nomenclature scripts
- [ADR-602](./602-DEVOPS-makefile-orchestrateur.md) - Makefile orchestrateur

## 📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-02-21 | @dev-team | Création ADR-603 | Adaptation depuis og-nore/ADR-609 pour smw-marketplace |
| 2026-03-04 | @michel-heon | Ajout section 7 : alignement tag Git = IMAGE_VERSION | Simplification traçabilité image Packer ↔ tag Git |

**Note** : Le versioning Marketplace (numérique pur) est automatiquement dérivé du tag Git par le pipeline CI/CD. Ne pas maintenir deux systèmes de version séparément.
