---
adr: 1
title: "Définition et Cadrage du Projet smw-marketplace"
status: "accepted"
date: 2026-04-01
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
    - "mediawiki"
    - "semantic-mediawiki"
    - "php"
    - "mysql"
    - "apache"
    - "tls"
    - "security"
    - "packer"

tags: ["project-definition", "scope", "strategy", "marketplace", "mediawiki", "smw", "vm-offer", "open-source", "knowledge-base"]
stakeholders: ["@architecture-team", "@dev-team", "@devops-team"]
effort: "high"
related_issues: []
related_adrs: [800]
replaces: null
superseded_by: null
---

# ADR 001: Définition et Cadrage du Projet smw-marketplace

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-04-01 |
| **Impact** | 🔴 Élevé (décision fondatrice — cadre tous les autres ADRs) |
| **Domaine** | META |
| **Réversibilité** | 🔴 Faible (engagement de long terme) |
| **Portée** | Projet complet |

## 🎯 Définition du Projet

> **Le projet consiste à industrialiser et publier sur Microsoft Azure Marketplace une offre de type Virtual Machine (VM) intégrant la solution open source Semantic MediaWiki (SMW) déployée sur Azure, utilisant MySQL comme base de données relationnelle et Apache + PHP-FPM comme couche web, destinée aux organisations souhaitant gérer une base de connaissances sémantique dans leur propre abonnement Azure. L'objectif est de fournir une image VM sécurisée, automatisée, conforme aux exigences Microsoft Marketplace, incluant l'installation complète (MySQL, Apache, PHP-FPM, MediaWiki, SMW, configuration TLS, sécurité réseau, monitoring), avec documentation, scripts de provisioning et conformité open source, afin de permettre un déploiement simple, reproductible et prêt pour la production dans l'environnement du client.**

## 🎯 Contexte et Problème

### Situation de départ

**Semantic MediaWiki (SMW)** est une extension open source de MediaWiki qui permet de stocker et d'interroger des données sémantiques directement dans un wiki. Utilisé par de nombreuses organisations pour gérer leurs bases de connaissances internes, son déploiement actuel est manuel, complexe, et requiert une expertise Linux, PHP, MySQL et Apache — ce qui freine son adoption.

**Problème** : Il n'existe pas d'offre standardisée, certifiée et prête à l'emploi permettant à une organisation de déployer Semantic MediaWiki en quelques clics via Azure Marketplace dans leur propre abonnement Azure.

### Opportunité

Microsoft Azure Marketplace permet de publier des offres de type **Virtual Machine** qui s'installent directement dans le tenant Azure du client. Ce modèle est idéal pour SMW car :
- Le client garde la **souveraineté totale** de ses données (MySQL dans son abonnement)
- Pas de dépendance à un SaaS tiers
- Conformité avec les politiques RGPD et de gouvernance des données
- Déploiement reproductible et versionné

## 💡 Décision

**Nous choisissons le type d'offre Azure Virtual Machine (VM)** pour la publication de Semantic MediaWiki sur Microsoft Azure Marketplace.

### Justification du type d'offre

| Type d'offre | Déploiement | Gestion | Complexité | Adapté SMW |
|--------------|-------------|---------|------------|------------|
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
| **Wiki Engine** | MediaWiki 1.43.x | Moteur wiki de base |
| **Extension sémantique** | Semantic MediaWiki 6.0.1 | Stockage et interrogation de données sémantiques |
| **Langage** | PHP 8.2 | Runtime PHP (compatible SMW 6.0.1, stable LTS-ready) |
| **Serveur web** | Apache 2.4 + PHP-FPM | Serveur HTTP et exécution PHP |
| **Base de données** | MySQL 8.x (SQLStore) | Base de données relationnelle principale |
| **Stockage médias** | File system + Azure Blob (optionnel) | Stockage des uploads wiki |
| **OS** | Ubuntu 22.04 LTS (Jammy) | Système d'exploitation (support jusqu'à 2027) |
| **Certificats TLS** | Let's Encrypt ou cert custom | HTTPS obligatoire |

### Architecture logique VM

```
┌───────────────────────────────────────────────────────────────┐
│  Azure VM (Standard_D2s_v3 minimum — 2 vCPU / 8 GB RAM)      │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Apache 2.4 + PHP-FPM (port 443 / 80)               │    │
│  │    └── MediaWiki + Semantic MediaWiki                │    │
│  └──────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  MySQL 8.x (port 3306 — localhost uniquement)        │    │
│  │    └── Base de données MediaWiki/SMW                 │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  OS Disk: Ubuntu 22.04 LTS (50 GB)                           │
│  Data Disk: 128 GB — MySQL + uploads + logs                  │
└───────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
  NSG (ports 443, 22)         Azure Monitor Agent
  Public IP                   Log Analytics Workspace
```

### Services Azure associés

| Service Azure | Usage |
|---------------|-------|
| **Azure VM** | Hôte principal MediaWiki/SMW |
| **Managed Disk (Premium SSD)** | OS disk (50 GB) + Data disk (128 GB) |
| **NSG** | Firewall réseau (ports 443/HTTPS, 22/SSH restreint) |
| **Azure Compute Gallery** | Stockage et versioning des images Packer |
| **Azure Monitor Agent** | Télémétrie OS et application |
| **Azure Backup** | Sauvegarde VM et données MySQL |
| **Azure Bastion** (optionnel) | Accès SSH sécurisé sans port 22 public |
| **Azure Blob Storage** (optionnel) | Stockage uploads alternatif |

---

## 📦 Stratégie de Packaging

### Outil de build image : Packer

L'image VM sera construite avec **HashiCorp Packer** (template HCL2) :

1. Base : Ubuntu 22.04 LTS (image endorsée Azure)
2. Provisioners Shell automatisés : PHP → Apache → MySQL → MediaWiki → SMW → TLS → Hardening → Azure Agent → Cleanup
3. Publication dans **Azure Compute Gallery** (versionnée)
4. Référencée depuis **Partner Center** pour publication Marketplace

### Paramètres exposés au déploiement client

Le client pourra configurer lors du déploiement (via ARM template) :
- Nom de domaine / hostname (`wikiUrl`)
- Adresse email administrateur (`wikiAdminEmail`)
- Mot de passe MySQL (`mysqlPassword`)
- Taille VM (SKU)
- Région Azure
- Clé SSH publique

### Nomenclature pipeline

L'image est publiée dans Azure Compute Gallery sous la convention :
`galSMWMarketplace/smw-wiki/{SMW_VERSION}.{YYYYMMDD}`
(ex. : `galSMWMarketplace/smw-wiki/6.0.1.20260401`)

---

## 🔒 Contraintes Sécurité

| Domaine | Exigence |
|---------|----------|
| **Authentification SSH** | Clés uniquement — password désactivé |
| **Ports NSG** | 443 (HTTPS), 22 (SSH restreint) uniquement exposés |
| **TLS** | TLS 1.2+ obligatoire, TLS 1.0/1.1 désactivés |
| **Credentials** | Aucun credential par défaut dans l'image |
| **MySQL** | Accès localhost uniquement par défaut |
| **Azure Marketplace** | Conforme aux tests de certification automatisés Microsoft |

---

## 💰 Modèle de Tarification

**Modèle retenu : BYOL (Bring Your Own License) + Free**

| Élément | Facturation |
|---------|-------------|
| Image MediaWiki + SMW | **Gratuite** (GPL-2.0, open source) |
| Compute Azure VM | Facturé par Microsoft directement au client |
| Support / services professionnels | Optionnel séparé |

**Justification** : MediaWiki et Semantic MediaWiki sont sous **licence GPL-2.0** — pas de licence logicielle commerciale à facturer. Le modèle BYOL/Free est conforme à l'esprit open source.

---

## 🎯 Marché Cible et Positionnement

### Segments cibles

| Segment | Besoin | Valeur proposition |
|---------|--------|--------------------|
| **Entreprises** | Base de connaissances sémantique interne, documentation structurée | Déploiement rapide, données dans leur Azure |
| **Organisations de recherche** | Gestion de connaissances, ontologies, linked data | SMW, données structurées interrogeables |
| **Organismes publics** | Conformité RGPD, souveraineté données | Isolation totale dans abonnement client |
| **Communautés wiki** | Migration ou nouvelle instance wiki sémantique | Image préconfigurée, prête à l'emploi |

### Différenciateurs

- **Déploiement en 1 clic** depuis Azure Marketplace (vs installation manuelle)
- **Données dans l'abonnement client** (souveraineté totale, conformité RGPD)
- **Image préconfigurée et durcie** (sécurité, TLS, monitoring inclus)
- **Versionnée et reproductible** (Packer + Compute Gallery)
- **Open source GPL-2.0** — pas de vendor lock-in

---

## 📅 Plan d'Exécution — 90 Jours

### Phase 1 — Infrastructure DevOps (Semaines 1-2)
- [ ] Environnement de développement (WSL2, PHP 8.2, Packer, Azure CLI)
- [ ] Structure du dépôt (`scripts/`, `packer/`, `config/`, `docs/adr/`)
- [ ] Bootstrap configuration (`env/.env.dev`, Makefile)
- [ ] ADRs fondateurs (META, DEVOPS, BIZ) ✅ **En cours**

### Phase 2 — Scripts d'Installation Reproductibles (Semaines 3-5)
- [ ] `packer/provisioners/install-php.sh`
- [ ] `packer/provisioners/install-apache.sh`
- [ ] `packer/provisioners/install-mysql.sh`
- [ ] `packer/provisioners/install-mediawiki.sh`
- [ ] `packer/provisioners/install-smw.sh`
- [ ] Tests d'installation locale (WSL2 + MySQL + Apache local)

### Phase 3 — Build Image Azure VM (Semaines 6-8)
- [ ] Template Packer HCL2 (`packer/smw-vm.pkr.hcl`)
- [ ] `packer/provisioners/install-azure-agent.sh`
- [ ] `packer/provisioners/configure-tls.sh`
- [ ] `packer/provisioners/security-harden.sh`
- [ ] `packer/provisioners/cleanup-before-generalize.sh`
- [ ] Premier build image (`make vm-build`)
- [ ] Publication dans Azure Compute Gallery (`galSMWMarketplace`)

### Phase 4 — Tests et Validation (Semaines 9-11)
- [ ] Smoke tests post-déploiement (`make vm-smoke-test`)
- [ ] Validation certification Microsoft (Certification Test Tool)
- [ ] Tests TLS, SSH, ports NSG
- [ ] Tests interface MediaWiki et extensions SMW
- [ ] Correction issues certification

### Phase 5 — Soumission Partner Center (Semaines 12-13)
- [ ] Création compte Partner Center + Offer ID `smw-knowledge-base`
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
- [ ] Annonce communauté MediaWiki / SMW

---

## ⚠️ Risques Critiques

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Certification rejet** (bash history, credentials, TLS) | Moyenne | Élevé | Script `cleanup-before-generalize.sh` + Certification Test Tool local (ADR-800) |
| **Licences open source** | Faible | Élevé | Voir section conformité ci-dessous |
| **Performance MediaWiki** (MySQL + uploads sur D2s_v3) | Faible | Moyen | Tests de charge avant publication |
| **Complexité provisioning** | Faible | Moyen | Scripts d'installation automatisés et testés |
| **Tenant Entra** (Gallery ≠ Partner Center) | Faible | Élevé | Vérifier alignment tenant dès création compte |

---

## 📜 Conformité Open Source

| Composant | Licence | Obligations |
|-----------|---------|-------------|
| **MediaWiki** | GPL-2.0+ | Mention copyright, inclusion LICENSE, pas de restriction redistribution |
| **Semantic MediaWiki** | GPL-2.0 | Idem |
| **PHP** | PHP License 3.x | Permissive, mention copyright |
| **MySQL Community** | GPL-2.0 | Usage distribution conforme GPL |
| **Apache HTTP Server** | Apache License 2.0 | Mention copyright, inclusion `NOTICE` |

**Obligations globales** :
- Inclure le fichier `LICENSE` (GPL-2.0) dans la documentation Marketplace
- Ne pas déposer de trademark sur les noms "MediaWiki" ou "Semantic MediaWiki" sans autorisation
- Mentionner les composants open source dans la description Marketplace

Le lien Terms of Use dans Partner Center pointera vers : `https://www.gnu.org/licenses/gpl-2.0.html`

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
| 2026-04-01 | @architecture-team | Création ADR-001 | Formalisation de la définition de projet SMW Marketplace |
