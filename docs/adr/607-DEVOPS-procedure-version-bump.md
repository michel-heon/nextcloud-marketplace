---
adr: 607
title: "Procédure de Bumping de Version — Image VM et Fichiers de Configuration"
status: "accepted"
date: 2026-03-07
superseded_by: null
replaces: null
related_adrs: [600, 603]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "medium"
  quality:
    - "maintainability"
    - "reliability"
    - "traceability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "packer"
    - "bash"
    - "azure"

tags: ["version-bump", "packer", "env", "bootstrap", "image-version", "arm", "bicep"]

stakeholders: ["@dev-team"]

effort: "low"
---

# ADR 607: Procédure de Bumping de Version — Image VM et Fichiers de Configuration

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-03-07 |
| **Stakeholders** | @dev-team |
| **Impact** | 🟡 Moyen |
| **Effort Implémentation** | 🟢 Faible |
| **Risque Technique** | 🟢 Faible |

---

## 🎯 Contexte & Problème

La version de l'image VM Azure est définie dans plusieurs fichiers :

```
env/.env.dev                        ← source canonique
env/generated/config.env            ← scripts Bash (source config.env)
env/generated/.env                  ← format dotenv
env/generated/config.make           ← Makefile (include config.make)
env/generated/packer-vars.json      ← Packer (-var-file)
arm/mainTemplate.bicep              ← imageId defaultValue (ARM/Marketplace)
arm/mainTemplate.json               ← compilé depuis le bicep (make arm-build)
```

Ces fichiers `env/generated/` sont **auto-générés** par `bootstrap.sh` à partir de `env/.env.dev`. Ils **ne doivent jamais être édités manuellement**.

Sans procédure claire, les bumps de version effectués directement dans `packer-vars.json` créent une **désynchronisation silencieuse** : la source canonique (`env/.env.dev`) reste à l'ancienne version tandis que les fichiers générés ont des valeurs incohérentes entre elles, selon lequel a été touché.

De plus, l'ADR-603 (section 7) impose que le **tag Git** soit identique à `IMAGE_VERSION` — cette règle ne peut être respectée que si la version est bumptée dans la source canonique avant de régénérer et de tagger.

---

## ✅ Décision

**Source unique de vérité** : `env/.env.dev` (variable `IMAGE_VERSION`).

Toute modification de version passe obligatoirement par :
1. Édition de `env/.env.dev` **et** mise à jour du `imageId` dans `arm/mainTemplate.bicep`
2. Régénération via `make setup` (qui invoque `bootstrap.sh`) + `make arm-build` (bicep → JSON)
3. Commit des fichiers source **et** générés
4. Tag Git aligné (conformément à ADR-603 §7)
5. Build Packer

Les fichiers `env/generated/` et `arm/mainTemplate.json` sont commités tels quels — ils sont générés mais versionnés pour garantir la reproductibilité sans nécessiter d'outillage supplémentaire dans les pipelines CI/CD.

---

## 🔁 Procédure Complète — Version Bump

> **Raccourci (étapes 1-3 automatisées)** :
> ```bash
> make version-bump              # patch : x.y.z → x.y.(z+1)
> make version-bump PART=minor   # minor : x.y.z → x.(y+1).0
> make version-bump PART=major   # major : x.y.z → (x+1).0.0
> make version-bump VERSION=2.3.0 # version explicite
> ```
> Délègue à `scripts/version-bump.sh` (ADR-602), qui exécute les étapes 1-3
> (dont la mise à jour de `arm/mainTemplate.bicep`) et affiche les commandes pour les étapes 4-6.
> Après le script, lancer `make arm-build` pour régénérer `arm/mainTemplate.json`.

### Étape 1 — Éditer la source canonique

```bash
# Ouvrir env/.env.dev et modifier IMAGE_VERSION
#   IMAGE_VERSION="1.1.0"  →  IMAGE_VERSION="1.1.1"
vim env/.env.dev
```

### Étape 1b — Mettre à jour arm/mainTemplate.bicep

```bash
# La valeur par défaut de imageId doit pointer vers la nouvelle version
# Automatisé par scripts/version-bump.sh (sed sur /versions/<old> → /versions/<new>)
vim arm/mainTemplate.bicep
# Puis recompiler :
make arm-build   # → arm/mainTemplate.json
```

### Étape 2 — Régénérer les fichiers de configuration

```bash
make setup
# Génère :
#   env/generated/config.env         (export IMAGE_VERSION="1.1.1")
#   env/generated/.env               (IMAGE_VERSION=1.1.1)
#   env/generated/config.make        (IMAGE_VERSION := "1.1.1")
#   env/generated/packer-vars.json   ("image_version": "1.1.1")
```

### Étape 3 — Vérifier la cohérence

```bash
grep IMAGE_VERSION env/.env.dev env/generated/config.env env/generated/config.make
grep image_version env/generated/packer-vars.json
# Toutes les lignes doivent afficher 1.1.1
```

### Étape 4 — Committer

```bash
git add env/.env.dev env/generated/ arm/mainTemplate.bicep arm/mainTemplate.json
git commit -m "chore: bump version to 1.1.1"
```

### Étape 5 — Créer le tag Git aligné (ADR-603 §7)

```bash
git tag -a v1.1.1-{description} -m "v1.1.1: {résumé des changements}"
git push origin --tags
```

### Étape 6 — Rebuilder l'image

```bash
make packer-build
```

---

## 🗂️ Fichiers de Configuration — Rôles et Consommateurs

| Fichier | Format | Consommé par | Mis à jour par |
|---------|--------|-------------|----------------|
| `env/.env.dev` | `VAR="valeur"` | Source canonique, `bootstrap.sh`, documentation | Manuel / `version-bump.sh` |
| `env/generated/config.env` | `export VAR="valeur"` | Scripts Bash (`source config.env`) | `make setup` |
| `env/generated/.env` | `VAR=valeur` | Docker Compose, outils dotenv | `make setup` |
| `env/generated/config.make` | `VAR := "valeur"` | `Makefile` (`include config.make`) | `make setup` |
| `env/generated/packer-vars.json` | JSON | Packer (`-var-file`) | `make setup` |
| `arm/mainTemplate.bicep` | Bicep | Source ARM / Partner Center | `version-bump.sh` (étape 1b) |
| `arm/mainTemplate.json` | JSON ARM | Partner Center, `az deployment` | `make arm-build` |

---

## ⚠️ Anti-Patterns à Éviter

| Anti-pattern | Risque |
|--------------|--------|
| Éditer `packer-vars.json` directement | Désynchronisation avec `config.env`, `config.make`; source canonique fausse |
| Éditer `config.env` ou `config.make` directement | Écrasés au prochain `make setup` sans avertissement |
| Éditer `arm/mainTemplate.json` directement | Écrasé au prochain `make arm-build`; désynchronisation avec le bicep |
| Oublier `make arm-build` après le bump | `mainTemplate.json` pointe encore vers l'ancienne version — échec Partner Center |
| Tag Git avec version différente de `IMAGE_VERSION` | Traçabilité image ↔ code impossible (ADR-603 §7) |
| Builder sans `make setup` après édition de `.env.dev` | Packer utilise l'ancienne version |

---

## ⚖️ Conséquences

### ✅ Positives

| Bénéfice | Description |
|----------|-------------|
| **Source unique de vérité** | Cohérence garantie entre tous les fichiers de config |
| **Reproductibilité** | Les fichiers générés commités permettent le build sans bootstrap préalable |
| **Traçabilité** | Alignement tag Git = IMAGE_VERSION (ADR-603 §7) |
| **Détection d'erreurs rapide** | Étape de vérification (grep) détecte immédiatement les désynchronisations |

### ⚠️ Négatives & Mitigations

| Inconvénient | Mitigation |
|--------------|------------|
| Doublon apparent (source + générés dans git) | Documenté ici; les générés sont commités intentionnellement |
| Risque d'oubli du `make setup` | Étape de vérification grep + convention de checklist |

---

## 📚 Références

- [ADR-600](./600-DEVOPS-bootstrap-configuration-management.md) — Bootstrap et gestion de la configuration
- [ADR-603](./603-DEVOPS-git-workflow-et-strategie-versioning.md) — Git Workflow et Stratégie de Versioning (§7 : alignement tag = IMAGE_VERSION)

---

## 📅 Historique des Révisions

| Date | Auteur | Changement | Raison |
|------|--------|-----------|--------|
| 2026-03-07 | @michel-heon | Création | Formalisation de la procédure suite au bump 1.1.0 → 1.1.1 |
| 2026-03-08 | @michel-heon | Ajout raccourci `make version-bump` | Extraction logique dans `scripts/version-bump.sh` (ADR-602 règle 3 lignes) |
| 2026-03-08 | @michel-heon | Ajout étape 1b : `arm/mainTemplate.bicep` + `make arm-build` | `imageId` defaultValue n'était pas mis à jour lors du bump — trou de procédure corrigé |
