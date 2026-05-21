---
# 🤖 Machine-Readable Metadata (Frontmatter YAML)
adr: 1
title: "Définition et Cadrage du Projet nextcloud-marketplace"
status: "accepted"
date: 2026-05-21
superseded_by: null
replaces: null
related_adrs: [800]
related_issues: []

# 🗂️ Taxonomie ADR
classification:
  lifecycle: "accepted"
  domain: "meta"
  impact: "high"
  quality:
    - "maintainability"
    - "compliance"
    - "portability"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "azure"
    - "marketplace"
    - "nextcloud"
    - "php"
    - "mariadb"
    - "nginx"
    - "tls"
    - "security"
    - "packer"

tags: ["project-definition", "scope", "strategy", "marketplace", "nextcloud", "vm-offer", "open-source", "file-sharing", "collaboration"]
stakeholders: ["@architecture-team", "@dev-team", "@devops-team"]
effort: "high"
---

# ADR 001: Définition et Cadrage du Projet nextcloud-marketplace

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-05-21 |
| **Impact** | 🔴 Élevé (décision fondatrice — cadre tous les autres ADRs) |
| **Domaine** | META |
| **Réversibilité** | 🔴 Faible (engagement de long terme) |
| **Portée** | Projet complet |

## 🎯 Définition du Projet

> **Le projet consiste à industrialiser et publier sur Microsoft Azure Marketplace une offre de type Virtual Machine (VM) intégrant la solution open source Nextcloud Hub déployée sur Azure, utilisant MariaDB comme base de données relationnelle et Nginx + PHP-FPM comme couche web, destinée aux organisations souhaitant gérer un serveur de fichiers collaboratif et de communication dans leur propre abonnement Azure. L'objectif est de fournir une image VM sécurisée, automatisée, conforme aux exigences Microsoft Marketplace, incluant l'installation complète (MariaDB, Nginx, PHP-FPM, Nextcloud, configuration TLS, sécurité réseau, monitoring), avec documentation, scripts de provisioning et conformité open source, afin de permettre un déploiement simple, reproductible et prêt pour la production dans l'environnement du client.**

## 🎯 Contexte et Problème

### Situation de départ

**Nextcloud Hub** est une suite de collaboration open source permettant le partage de fichiers, la visioconférence, la messagerie, la gestion de calendriers et de contacts. Alternative souveraine à Microsoft OneDrive/SharePoint ou Google Drive, son déploiement actuel est manuel, complexe, et requiert une expertise Linux, PHP, MariaDB et Nginx — ce qui freine son adoption en entreprise.

**Problème** : Il n'existe pas d'offre standardisée, certifiée et prête à l'emploi permettant à une organisation de déployer Nextcloud Hub en quelques clics via Azure Marketplace dans leur propre abonnement Azure.

### Opportunité

Microsoft Azure Marketplace permet de publier des offres de type **Virtual Machine** qui s'installent directement dans le tenant Azure du client. Ce modèle est idéal pour Nextcloud car :

- Le client garde la **souveraineté totale** de ses données (MariaDB + fichiers dans son abonnement)
- Pas de dépendance à un SaaS tiers
- Conformité avec les politiques RGPD et de gouvernance des données
- Déploiement reproductible et versionné

## 💡 Décision

**Nous choisissons le type d'offre Azure Virtual Machine (VM)** pour la publication de Nextcloud Hub sur Microsoft Azure Marketplace.

### Justification du type d'offre

| Type d'offre | Déploiement | Gestion | Complexité | Adapté Nextcloud |
|--------------|-------------|---------|------------|------------------|
| **Virtual Machine (VM)** ✅ | Dans le cloud du client | Client | Faible à modérée | ✅ **Retenu** |
| SaaS | Hébergé publisher | Publisher | Élevée (SaaS Fulfillment API, multitenant) | ❌ Trop complexe, données hors tenant client |
| Container | Dans le cloud du client | Client | Modérée à élevée | ⚠️ Possible évolution future |
| Managed Application | Dans le cloud du client | Partagé | Modérée | ⚠️ Sur-ingénierie pour MVP |

**Modèle retenu** : `Bring Your Own Subscription (BYOS)` — le client déploie dans son propre abonnement Azure.

---

## 🏗️ Architecture Technique Cible

### Stack applicative

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| **Plateforme collaborative** | Nextcloud Hub (dernière version stable) | Fichiers, Talk, Groupware, Office |
| **Langage** | PHP 8.2 | Runtime PHP (compatible NC29+, NC30+, NC31+) |
| **Serveur web** | Nginx + PHP-FPM | Serveur HTTP et exécution PHP |
| **Base de données** | MariaDB 10.6+ | Base de données relationnelle principale |
| **Cache / File locking** | Redis (optionnel — recommandé) | Cache APCu + verrous fichiers |
| **Stockage fichiers** | File system local (data disk dédié) | Données utilisateurs Nextcloud |
| **OS** | Ubuntu 22.04 LTS (Jammy) | Système d'exploitation (support jusqu'à 2027) |
| **Certificats TLS** | Let's Encrypt ou cert custom | HTTPS obligatoire |

### Architecture logique VM

```
┌─────────────────────────────────────────────────────────────────────┐
│  Azure VM (Standard_D2s_v3 minimum — 2 vCPU / 8 GB RAM)            │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Nginx + PHP 8.2-FPM (port 443 / 80)                      │    │
│  │    └── Nextcloud Hub (Files, Talk, Groupware, Office)      │    │
│  └────────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  MariaDB 10.6+ (port 3306 — localhost uniquement)          │    │
│  │    └── Base de données Nextcloud                           │    │
│  └────────────────────────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Redis (port 6379 — localhost uniquement, optionnel)       │    │
│  │    └── Cache sessions + file locking APCu                  │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  OS Disk: Ubuntu 22.04 LTS (50 GB)                                 │
│  Data Disk: 256 GB — données Nextcloud + MariaDB + logs            │
└─────────────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
  NSG (ports 443, 22)         Azure Monitor Agent
  Public IP                   Log Analytics Workspace
```

### Services Azure associés

| Service Azure | Usage |
|---------------|-------|
| **Azure VM** | Hôte principal Nextcloud Hub |
| **Managed Disk (Premium SSD)** | OS disk (50 GB) + Data disk (256 GB) |
| **NSG** | Firewall réseau (ports 443/HTTPS, 22/SSH restreint) |
| **Azure Compute Gallery** | Stockage et versioning des images Packer |
| **Azure Monitor Agent** | Télémétrie OS et application |
| **Azure Backup** | Sauvegarde VM et données MariaDB |
| **Azure Bastion** (optionnel) | Accès SSH sécurisé sans port 22 public |

---

## 📦 Stratégie de Packaging

### Outil de build image : Packer

L'image VM sera construite avec **HashiCorp Packer** (template HCL2) :

1. Base : Ubuntu 22.04 LTS (image endorsée Azure)
2. Provisioners Shell automatisés : PHP → Nginx → MariaDB → Redis → Nextcloud → TLS → Hardening → Azure Agent → Cleanup
3. Publication dans **Azure Compute Gallery** (versionnée)
4. Référencée depuis **Partner Center** pour publication Marketplace

### Paramètres exposés au déploiement client

Le client pourra configurer lors du déploiement (via ARM template) :

- Nom de domaine / hostname (`nextcloudHostname`)
- Adresse email administrateur Nextcloud (`adminEmail`)
- Mot de passe base de données MariaDB (`dbPassword`)
- Clé SSH publique (`adminPublicKey`)
- Taille VM (`vmSize`, défaut `Standard_D2s_v3`)
- Taille du disque données (`dataDiskSizeGB`, défaut `256`)
- Région Azure

### Nomenclature pipeline

L'image est publiée dans Azure Compute Gallery sous la convention :

`galNCMarketplace/nextcloud/{NC_VERSION}.{YYYYMMDD}`

(ex. : `galNCMarketplace/nextcloud/31.0.0.20260521`)

---

## 🔒 Contraintes Sécurité

| Domaine | Exigence |
|---------|----------|
| **Authentification SSH** | Clés uniquement — password désactivé |
| **Ports NSG** | 443 (HTTPS), 22 (SSH restreint) uniquement exposés |
| **TLS** | TLS 1.2+ obligatoire, TLS 1.0/1.1 désactivés |
| **Credentials** | Aucun credential par défaut dans l'image |
| **MariaDB** | Accès localhost uniquement par défaut |
| **Nextcloud** | `occ config:system:set trusted_domains` configuré au premier boot |
| **Azure Marketplace** | Conforme aux tests de certification automatisés Microsoft |

---

## 💰 Modèle de Tarification

**Modèle retenu : BYOL (Bring Your Own License) + Free**

| Élément | Facturation |
|---------|-------------|
| Image Nextcloud Hub | **Gratuite** (AGPL-3.0, open source) |
| Compute Azure VM | Facturé par Microsoft directement au client |
| Support / services professionnels | Optionnel séparé |

**Justification** : Nextcloud est sous **licence AGPL-3.0** — pas de licence logicielle commerciale à facturer. Le modèle BYOL/Free est conforme à l'esprit open source. Note : la licence AGPL-3.0 exige que toute modification apportée à Nextcloud soit publiée sous les mêmes termes si le service est utilisé en réseau.

---

## 🎯 Marché Cible et Positionnement

### Segments cibles

| Segment | Besoin | Valeur proposition |
|---------|--------|--------------------|
| **Entreprises** | Partage de fichiers souverain, alternative à OneDrive/SharePoint | Déploiement rapide, données dans leur Azure |
| **Organisations de recherche** | Collaboration et partage de données, conformité RGPD | Nextcloud isolé dans l'abonnement client |
| **Organismes publics** | Conformité RGPD, souveraineté données, cloud européen | Isolation totale dans abonnement client |
| **PME et équipes distribuées** | Suite collaboration complète sans dépendance SaaS | Image préconfigurée, prête à l'emploi |

### Différenciateurs

- **Déploiement en 1 clic** depuis Azure Marketplace (vs installation manuelle)
- **Données dans l'abonnement client** (souveraineté totale, conformité RGPD)
- **Image préconfigurée et durcie** (sécurité, TLS, monitoring inclus)
- **Versionnée et reproductible** (Packer + Compute Gallery)
- **Open source AGPL-3.0** — pas de vendor lock-in

---

## 📅 Plan d'Exécution — 90 Jours

### Phase 1 — Infrastructure DevOps (Semaines 1-2)
- [ ] Environnement de développement (WSL2/Linux, PHP 8.2, Packer, Azure CLI)
- [ ] Structure du dépôt (`scripts/`, `packer/`, `config/`, `docs/adr/`)
- [ ] Bootstrap configuration (`env/.env.dev`, Makefile)
- [ ] ADRs fondateurs (META, DEVOPS, BIZ) ✅ **En cours**

### Phase 2 — Scripts d'Installation Reproductibles (Semaines 3-5)
- [ ] `packer/provisioners/install-php.sh`
- [ ] `packer/provisioners/install-nginx.sh`
- [ ] `packer/provisioners/install-mariadb.sh`
- [ ] `packer/provisioners/install-redis.sh`
- [ ] `packer/provisioners/install-nextcloud.sh`
- [ ] Tests d'installation locale (WSL2 + MariaDB + Nginx local)

### Phase 3 — Build Image Azure VM (Semaines 6-8)
- [ ] Template Packer HCL2 (`packer/nextcloud-vm.pkr.hcl`)
- [ ] `packer/provisioners/install-azure-agent.sh`
- [ ] `packer/provisioners/configure-tls.sh`
- [ ] `packer/provisioners/security-harden.sh`
- [ ] `packer/provisioners/cleanup-before-generalize.sh`
- [ ] Premier build image (`make vm-build`)
- [ ] Publication dans Azure Compute Gallery (`galNCMarketplace`)

### Phase 4 — Tests et Validation (Semaines 9-11)
- [ ] Smoke tests post-déploiement (`make vm-smoke-test`)
- [ ] Validation certification Microsoft (Certification Test Tool)
- [ ] Tests TLS, SSH, ports NSG
- [ ] Tests interface Nextcloud et fonctionnalités (Files, Talk, Groupware)
- [ ] Correction issues certification

### Phase 5 — Soumission Partner Center (Semaines 12-13)
- [ ] Création compte Partner Center + Offer ID `nextcloud-server`
- [ ] Permissions Azure Compute Gallery (`make marketplace-gallery-permissions`)
- [ ] Rédaction listing (titre, description, logo, screenshots)
- [ ] Configuration plan VM + data disk
- [ ] Configuration customer leads
- [ ] Soumission pour certification Microsoft

### Phase 6 — Publication et Go-to-Market (Semaine 14+)
- [ ] Review certification Microsoft
- [ ] Corrections si nécessaire
- [ ] Validation Preview Audience
- [ ] **Go Live** sur Azure Marketplace
- [ ] Annonce communauté Nextcloud

---

## ⚠️ Risques Critiques

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Certification rejet** (bash history, credentials, TLS) | Moyenne | Élevé | Script `cleanup-before-generalize.sh` + Certification Test Tool local (ADR-800) |
| **Licences open source** | Faible | Élevé | Voir section conformité ci-dessous |
| **Performance Nextcloud** (MariaDB + fichiers sur D2s_v3) | Faible | Moyen | Tests de charge avant publication, Redis recommandé |
| **Complexité provisioning** | Faible | Moyen | Scripts d'installation automatisés et testés |
| **Tenant Entra** (Gallery ≠ Partner Center) | Faible | Élevé | Vérifier alignment tenant dès création compte |
| **Croissance disque données** | Moyen | Moyen | Data disk séparé (256 GB configurable), documentation backup |

---

## 📜 Conformité Open Source

| Composant | Licence | Obligations |
|-----------|---------|-------------|
| **Nextcloud Hub** | AGPL-3.0 | Les modifications doivent être publiées en AGPL-3.0 si le service est exposé en réseau |
| **PHP** | PHP License 3.x | Permissive, mention copyright |
| **MariaDB Community** | GPL-2.0 | Usage distribution conforme GPL |
| **Nginx** | BSD 2-Clause | Mention copyright |
| **Redis** | BSD 3-Clause (≤ 7.2) | Mention copyright — ⚠️ Redis ≥ 7.4 passe sous SSPL/RSALv2 |

**Obligations globales** :

- Inclure le fichier `LICENSE` (AGPL-3.0) dans la documentation Marketplace
- Ne pas déposer de trademark sur le nom « Nextcloud » sans autorisation (Nextcloud GmbH)
- Mentionner les composants open source dans la description Marketplace

Le lien Terms of Use dans Partner Center pointera vers : `https://www.gnu.org/licenses/agpl-3.0.html`

---

## 🔗 Traçabilité des Décisions

| Décision | ADR |
|----------|-----|
| Bootstrap configuration management | [ADR-600](./600-DEVOPS-bootstrap-configuration-management.md) |
| Nomenclature scripts | [ADR-601](./601-DEVOPS-nomenclature-scripts.md) |
| Makefile orchestrateur | [ADR-602](./602-DEVOPS-makefile-orchestrateur.md) |
| Git workflow et versioning | [ADR-603](./603-DEVOPS-git-workflow-et-strategie-versioning.md) |
| Modularisation scripts | [ADR-604](./604-DEVOPS-modularisation-scripts-partages.md) |
| Stratégie version PHP | [ADR-609](./609-DEVOPS-php-version-strategy.md) |
| Publication Azure Marketplace | [ADR-800](./800-BIZ-publication-azure-marketplace-vm-offer.md) |

---

## 📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-05-21 | @architecture-team | Création ADR-001 | Formalisation de la définition de projet nextcloud-marketplace (adapté depuis nextcloud-marketplace) |
