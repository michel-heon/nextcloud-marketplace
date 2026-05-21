---
adr: 601
title: "Nomenclature des Scripts et Règles Makefile"
status: "accepted"
date: 2026-02-21
classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "low"
  quality: ["maintainability", "discoverability"]
  reversibility: "easy"
  scope: "tactical"
  tech_areas: ["bash", "makefile", "automation", "devops", "naming", "packer"]
tags: ["devops", "scripting", "bash", "makefile", "naming", "packer", "nextcloud-marketplace"]
stakeholders: ["@devops-team", "@dev-team"]
effort: "low"
related_issues: []
related_adrs: [602, 600, 608]
replaces: null
superseded_by: null
---

# ADR 601: Nomenclature des Scripts et Règles Makefile

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-02-21 |
| **Impact** | 🟢 Faible (conventions scripts) |
| **Domaine** | DevOps |
| **Réversibilité** | 🟢 Élevée (renommage scripts) |
| **Portée** | Projet complet |

## 🎯 Contexte

Le projet nextcloud-marketplace comprend des scripts d'automatisation pour :
- **Construction image VM** : Scripts Packer, provisioning Nextcloud/Nginx/MariaDB
- **Tests et validation** : Smoke tests VM, vérification TLS, test Marketplace
- **Infrastructure Azure** : Déploiement ressources, gestion Resource Groups
- **Configuration Nextcloud : configuration Nextcloud, setup Nginx, configuration MariaDB

Sans convention de nommage claire :
- **Difficulté de découverte** : Les développeurs ne trouvent pas le script voulu
- **Inconsistance** : Styles mélangés (`deploy.sh`, `nextcloud-install.sh`, `nginx_install.sh`)
- **Maintenance complexe** : Difficile de comprendre rapidement la fonction d'un script

## Décision

Adopter une nomenclature standardisée pour **tous les scripts d'automatisation** (Bash) et **règles Makefile** selon le format :

```
{object}-{action}.{ext}
```

### Règles de Nomenclature

1. **Format obligatoire** : `{object}-{action}.{ext}`
   - `{object}` : Composant/domaine concerné (nom singulier ou composé)
   - `{action}` : Action effectuée (verbe infinitif)
   - Séparateur : tiret (`-`)
   - Extension : `.sh` (Bash), `.py` (Python utilitaires)

2. **Conventions**
   - **Tout en minuscules** (lowercase)
   - **Mots séparés par des tirets**
   - **Objet au singulier** : `vm`, `nextcloud`, `nginx`, `mariadb`, `redis`, `tls`
   - **Action en verbe** : `install`, `configure`, `start`, `stop`, `test`, `validate`, `build`

3. **Exemples valides**

   **Scripts provisioning VM** :
   ```
   vm-provision.sh             # Provisioning complet VM
   vm-validate.sh              # Validation image VM
   vm-smoke-test.sh            # Tests smoke post-déploiement
   ```

   **Scripts composants Nextcloud** :
   ```
   nextcloud-install.sh             # Installation Nextcloud
   nextcloud-configure.sh           # Configuration post-installation
   nextcloud-start.sh               # Démarrage services Nextcloud
   nginx-install.sh             # Installation et configuration Nginx
   nginx-configure.sh            # Configuration Nginx (nginx.conf, sites, etc.)
   mariadb-install.sh              # Installation MariaDB
   mariadb-configure.sh          # Configuration MariaDB (bases, schémas)
   nextcloud-install.sh                # Installation Nextcloud apps
   nextcloud-configure.sh              # Configuration Nextcloud
   ```

   **Scripts sécurité** :
   ```
   tls-configure.sh            # Configuration certificats TLS
   tls-validate.sh             # Validation TLS (grade, expiry)
   firewall-configure.sh       # Configuration règles firewall NSG
   security-harden.sh          # Hardening sécurité VM
   ```

   **Scripts Azure Marketplace** :
   ```
   marketplace-validate.sh     # Validation pré-certification
   marketplace-publish.sh      # Publication offre Marketplace
   image-build.sh              # Build image Packer
   image-validate.sh           # Validation image Azure
   ```

   **Scripts Azure infrastructure** :
   ```
   azure-login.sh              # Authentification Azure CLI
   azure-rg-create.sh          # Création Resource Group
   azure-vm-deploy.sh          # Déploiement VM test
   azure-vm-destroy.sh         # Nettoyage VM test
   ```

4. **Convention spéciale: Composants Nextcloud individuels**

   Pour scripts qui gèrent des composants individuels de la stack Nextcloud :

   **Format** : `{composant}-{action}.sh`

   ```bash
   # Composant-action cohérent
   nextcloud-install.sh              # Nextcloud core
   mariadb-install.sh               # MariaDB spécifiquement
   nextcloud-reindex.sh                  # Réindexation Nextcloud
   nextcloud-extensions-install.sh       # Apps Nextcloud additionnelles
   jena-fuseki-install.sh       # Serveur Fuseki SPARQL
   ```

5. **Règles Makefile**

   Les targets Makefile suivent une convention similaire **sans extension** :

   **Format général** : `{object}-{action}` ou `{action}` (verbe seul pour targets standards)

   ```makefile
   # Targets standards (exemptions)
   help, setup, clean, test, build, deploy

   # Targets composants (object-action)
   nextcloud-install           # Installe Nextcloud
   nextcloud-configure         # Configure Nextcloud
   nginx-install              # Installe Nginx
   mariadb-install            # Installe MariaDB
   tls-configure          # Configure TLS
   vm-build               # Build image VM Packer
   vm-validate            # Valide image
   marketplace-validate   # Validation Marketplace
   ```

6. **Organisation dans `scripts/`**

   ```
   scripts/
   ├── README.md                          # Documentation des scripts
   │
   ├── # Provisioning VM
   ├── vm-provision.sh                    # Orchestrateur provisioning complet
   ├── vm-validate.sh                     # Validation post-build
   ├── vm-smoke-test.sh                   # Smoke tests
   │
   ├── # Nextcloud Stack
   ├── nextcloud-install.sh             # Installation Nextcloud
   ├── nextcloud-configure.sh                  # Configuration Nextcloud
   ├── mariadb-install.sh                            # MariaDB
   ├── nginx-install.sh                           # Nginx
   ├── nginx-configure.sh                          # Configuration Nginx
   ├── nextcloud-install.sh                              # Nextcloud apps
   ├── nextcloud-configure.sh                            # Configuration Nextcloud
   │
   ├── # Sécurité
   ├── tls-configure.sh                   # TLS/HTTPS
   ├── firewall-configure.sh              # NSG / iptables
   ├── security-harden.sh                 # Hardening OS
   │
   ├── # Azure
   ├── azure-login.sh                     # Authentification
   ├── azure-rg-create.sh                 # Resource Group
   ├── image-build.sh                     # Packer build
   ├── image-validate.sh                  # Validation image
   └── marketplace-validate.sh            # Validation Marketplace
   ```

### Exemples de Migration

**Avant (❌ non-standard) :**
```bash
scripts/nextcloud-install.sh           # camelCase
scripts/install_nginx.sh      # underscore
scripts/DeployVM.sh            # Majuscule
scripts/setup.sh               # Nom générique
scripts/azure-deploy-vm.sh     # Action avant objet
```

**Après (✅ standard ADR-601) :**
```bash
scripts/server-install.sh        # object-action, lowercase
scripts/nginx-install.sh      # tirets
scripts/vm-deploy.sh           # lowercase
scripts/vm-provision.sh        # descriptif
scripts/azure-vm-deploy.sh     # azure-{service}-{action}
```

## Conséquences

### Positives ✅

- **Prévisibilité** : Le nom révèle immédiatement le composant et l'action
- **Découvrabilité** : `ls scripts/nextcloud-*` liste tous les scripts Nextcloud
- **Cohérence** : Pattern uniforme Bash + Makefile
- **Auto-complétion** : `nextcloud-<TAB>` liste les scripts Nextcloud
- **Compatibilité Packer** : Noms utilisés comme `scripts/` dans provisioners Packer

### Négatives ⚠️

- **Migration** : Scripts existants à renommer dès le début du projet
- **Discipline** : Nécessite rigueur sur la durée

## Alternatives Considérées

### Action-Object (`install-nextcloud.sh`)
**Rejetée** : Moins intuitif pour regrouper par composant. `ls scripts/server-*` plus utile que `ls scripts/install-*`.

### CamelCase (`installVivo.sh`)
**Rejetée** : Non-conforme conventions Unix/Linux.

### Underscore (`vivo_install.sh`)
**Rejetée** : Tirets préférés dans l'écosystème Linux moderne.

## 🚀 Plan d'Implémentation

- [x] Définir et documenter la convention (cet ADR)
- [ ] Créer `scripts/README.md` avec liste des scripts disponibles
- [ ] Appliquer convention dès création des premiers scripts
- [ ] Vérification convention dans code review PR

## 🔗 Traçabilité & Liens

- [ADR-600](./600-DEVOPS-bootstrap-configuration-management.md) - Configuration bootstrap
- [ADR-602](./602-DEVOPS-makefile-orchestrateur.md) - Makefile orchestrateur

## 📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-02-21 | @dev-team | Création ADR-601 | Adaptation depuis og-nore/ADR-601 pour nextcloud-marketplace |
