---
adr: 303
title: "Permissions RBAC Azure Compute Gallery pour Partner Center — Visibilité Images VM"
status: "accepted"
date: 2026-05-19
superseded_by: null
replaces: null
related_adrs: [200, 800]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "security"
  impact: "critical"
  quality:
    - "security"
    - "compliance"
    - "reliability"
  reversibility: "easy"
  scope: "operational"
  tech_areas:
    - "azure"
    - "marketplace"

tags: ["azure-marketplace", "rbac", "compute-gallery", "partner-center", "iam", "service-principal", "publisher-id"]
stakeholders: ["@devops-team", "@architecture-team"]
effort: "low"
---

# ADR-303 : Permissions RBAC Azure Compute Gallery pour Partner Center

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-05-19 |
| **Impact** | 🔴 Critique (images VM invisibles dans Partner Center sans ce prérequis) |
| **Risque technique** | 🔴 Élevé (bloque la publication sur Azure Marketplace) |
| **Portée** | Opérationnelle — configuration RBAC + cohérence champ `publisher` |

---

## 🎯 Contexte

Partner Center doit accéder à une **Azure Compute Gallery** pour lire les images VM lors de la configuration technique d'une offre. Cet accès repose sur deux conditions indépendantes qui doivent être remplies **simultanément** :

1. **Condition RBAC** — Deux Service Principals Microsoft doivent posséder le rôle `Compute Gallery Image Reader` sur la gallery.
2. **Condition publisher-match** — Le champ `publisher` de chaque image definition doit correspondre exactement au **Publisher ID du compte Partner Center** de l'éditeur.

L'absence de l'une ou l'autre de ces conditions provoque une invisibilité **silencieuse** : aucun message d'erreur n'est affiché dans Partner Center, le dropdown "Gallery image" apparaît vide.

**Référence Microsoft** : [aka.ms/ComputeGalleryPermissions](https://aka.ms/ComputeGalleryPermissions)

---

## 🔍 Problème Découvert (Post-Mortem)

### Chronologie

| Étape | Constat |
|-------|---------|
| Première tentative Partner Center | `smw-knowledge-base` absent du dropdown "Gallery image" |
| Vérification RBAC | Rôles non assignés → assignés (`make marketplace-gallery-permissions`) |
| Deuxième tentative Partner Center | Toujours absent |
| Diagnostic comparatif (DSpace visible ✅, SMW absent ❌) | `publisher` de DSpace = `Cotechnoe`, `publisher` de SMW = `SMWMarketplace` |
| Correction | Recréation de la définition avec `--publisher cotechnoe` |
| Troisième tentative Partner Center | `smw-knowledge-base` visible ✅ |

### Root Cause : Deux bugs distincts, résolution séquentielle

**Bug 1 — RBAC manquant** :
Les deux Service Principals Microsoft n'avaient pas le rôle `Compute Gallery Image Reader` sur la gallery `galSMWMarketplace`.

```
SP manquants :
  Microsoft Partner Center Resource Provider  (497d76fa-f477-478a-aa29-49b0dee35030)
  Compute Image Registry                      (5947d96b-019a-46ba-ad4b-8ffc6f493b2e)
```

**Bug 2 — Publisher mismatch** :
L'image definition `smw-knowledge-base` avait été créée avec `--publisher SMWMarketplace` au lieu de `--publisher cotechnoe`. Partner Center filtre silencieusement les definitions dont le `publisher` ne correspond pas à l'identifiant de l'éditeur.

```json
// Avant (invisible)
"identifier": { "publisher": "SMWMarketplace", "offer": "smw-knowledge-base", "sku": "22_04-lts-gen2" }

// Après (visible)
"identifier": { "publisher": "cotechnoe", "offer": "smw-knowledge-base", "sku": "22_04-lts-gen2" }
```

---

## 💡 Décisions

### Décision 1 — Assignation RBAC des SPs Microsoft

Assigner le rôle `Compute Gallery Image Reader` aux deux SPs Microsoft sur la gallery `galSMWMarketplace` :

| Service Principal | Object ID | Rôle |
|------------------|-----------|------|
| Microsoft Partner Center Resource Provider | `497d76fa-f477-478a-aa29-49b0dee35030` | `Compute Gallery Image Reader` |
| Compute Image Registry | `5947d96b-019a-46ba-ad4b-8ffc6f493b2e` | `Compute Gallery Image Reader` |

**Automatisation** : `make marketplace-gallery-permissions` → `packer/scripts/marketplace-gallery-permissions.sh`

La commande est idempotente (skip si rôle déjà assigné) et peut être rejouée sans risque.

### Décision 2 — Publisher = Partner Center Publisher ID

Le champ `publisher` de chaque image definition doit être le **Publisher ID exact du compte Partner Center** (`cotechnoe`), pas un nom arbitraire.

- Variable centralisée dans `env/.env.dev` : `GALLERY_IMAGE_PUBLISHER="cotechnoe"`
- Utilisée à la création : `az sig image-definition create --publisher "${GALLERY_IMAGE_PUBLISHER}"`
- Documentée dans `env/.env.dev` avec un commentaire explicite sur la contrainte Partner Center

**Choix `env/.env.dev` vs `env/.env.dev.user`** : Cette valeur est identique pour tous les contributeurs du projet (elle identifie le compte Partner Center de l'organisation, pas un utilisateur). Elle est versionnée dans Git via `.env.dev`.

### Décision 3 — Script de recréation idempotent

Lorsque le champ `publisher` d'une définition existante est incorrect, la **seule solution** est de supprimer et recréer la définition (Azure ne permet pas de modifier ce champ en place). Le script `packer/scripts/marketplace-gallery-recreate.sh` automatise cette séquence :

1. Inventaire des versions existantes (sauvegarde pour idempotence)
2. Suppression des versions
3. Suppression de la définition
4. Recréation avec `--publisher "${GALLERY_IMAGE_PUBLISHER}"`
5. Recréation des versions depuis les sources sauvegardées ou la managed image courante

**Automatisation** : `make marketplace-gallery-recreate`

### Décision 4 — Enregistrement RP Microsoft.PartnerCenterIngestion

Le Resource Provider `Microsoft.PartnerCenterIngestion` doit être enregistré sur la subscription pour permettre l'intégration Partner Center ↔ Compute Gallery.

```bash
az provider register --namespace Microsoft.PartnerCenterIngestion --wait
```

Vérifié idempotent dans le script (skip si déjà `Registered`).

---

## ⚠️ Contraintes et Règles

| Règle | Description |
|-------|-------------|
| **Publisher immuable** | Le champ `publisher` d'une image definition ne peut pas être modifié après création. Toute correction nécessite suppression + recréation avec perte des versions (à recréer depuis les managed images). |
| **Publisher = Partner Center ID** | La valeur doit correspondre exactement au Publisher ID du compte Partner Center (case-insensitive selon Azure, mais utiliser la casse officielle `cotechnoe`). |
| **RBAC scope gallery** | Les rôles sont assignés au niveau de la **gallery** (pas du resource group ni de la subscription). La portée minimale est recommandée (principe du moindre privilège). |
| **RP obligatoire** | `Microsoft.PartnerCenterIngestion` doit être `Registered` sur la subscription avant toute opération Partner Center → Gallery. |
| **Délai propagation** | Après assignation RBAC ou recréation de définition, attendre 5-10 minutes avant de vérifier dans Partner Center. |

---

## 🔧 Implémentation

### Commandes Makefile

```bash
# Assigner RBAC (idempotent, peut être rejoué)
make marketplace-gallery-permissions

# Recréer la définition avec publisher correct (si publisher incorrect)
make marketplace-gallery-recreate

# Les deux en séquence (recreate appelle permissions automatiquement)
make marketplace-gallery-recreate
```

### Scripts concernés

| Script | Rôle |
|--------|------|
| `packer/scripts/marketplace-gallery-permissions.sh` | RBAC : enregistrement RP + assignation rôles SPs |
| `packer/scripts/marketplace-gallery-recreate.sh` | Recréation définition + versions depuis managed image |

### Variables de configuration

```bash
# env/.env.dev
GALLERY_NAME="galSMWMarketplace"
GALLERY_IMAGE_NAME="smw-knowledge-base"
GALLERY_RESOURCE_GROUP="rg-smw-marketplace"
# Publisher de l'image definition — doit correspondre au Partner Center ID (ADR-800)
GALLERY_IMAGE_PUBLISHER="cotechnoe"
```

---

## ✅ Alternatives Rejetées

| Alternative | Raison du rejet |
|-------------|----------------|
| Modifier `publisher` via `az sig image-definition update` | Impossible — ce champ est immuable après création (Azure API 400 Bad Request) |
| Stocker `GALLERY_IMAGE_PUBLISHER` dans `.env.dev.user` | Valeur organisationnelle (pas per-user) — doit être versionnée et partagée |
| Assigner RBAC au niveau subscription | Sur-privilegié — principe du moindre privilège exige le scope gallery |
| Confier l'assignation RBAC au déploiement ARM | Hors scope Packer — appartient au workflow Partner Center, géré séparément |

---

## 📊 Conséquences

### Positives
- ✅ Images VM visibles dans Partner Center → publication possible
- ✅ Configuration RBAC reproductible et idempotente via Makefile
- ✅ Valeur `GALLERY_IMAGE_PUBLISHER` centralisée et versionnée

### Risques résiduels
- ⚠️ Si le Publisher ID Partner Center change (rare), il faut rejouer `make marketplace-gallery-recreate` sur toutes les définitions existantes
- ⚠️ La suppression des versions lors de la recréation est irréversible si les managed images sources ont été supprimées entre-temps → **ne jamais supprimer les managed images avant confirmation Partner Center**

---

## 🔗 Références

- [Azure Compute Gallery permissions for Partner Center](https://aka.ms/ComputeGalleryPermissions)
- [ADR-200](./200-INFRA-azure-infrastructure-vm-offer.md) — Infrastructure Azure Compute Gallery
- [ADR-800](./800-BIZ-publication-azure-marketplace-vm-offer.md) — Publication offre VM Marketplace
