---
adr: 803
title: "Titre Offre Azure Marketplace — Conformité Marques Tierces (Microsoft & Wikimedia)"
status: "accepted"
date: 2026-05-21
superseded_by: null
replaces: null
related_adrs: [800, 802]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "business"
  impact: "high"
  quality:
    - "compliance"
    - "usability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "marketplace"

tags: ["azure-marketplace", "certification", "partner-center", "trademark", "listing-title", "100.1.1.1", "100.7.1", "wikimedia-trademark"]
stakeholders: ["@dev-team", "@architecture-team"]
effort: "low"
---

# ADR 803: Titre Offre Azure Marketplace — Conformité Marques Tierces (Microsoft & Wikimedia)

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-05-21 |
| **Stakeholders** | @dev-team, @architecture-team |
| **Impact** | 🔴 Élevé (bloquant certification) |
| **Effort Implémentation** | 🟢 Faible (changement Partner Center) |
| **Risque Technique** | 🟢 Faible |

---

## 🎯 Contexte & Problème

### Problème

Lors de la soumission du 05/20/2026, le rapport de certification Azure Marketplace a retourné le statut **"Attention needed"** avec l'erreur suivante :

> **100.1.1.1 — Inaccurate title**  
> "The offer listing contains Microsoft trademarked or copyrighted material in [Listing Title]."

Le titre soumis était : **`Nextcloud Hub Cloud Edition — Azure Virtual Machines`**

L'expression **"Azure Virtual Machines"** est une marque déposée de Microsoft. Son utilisation directe dans le titre d'une offre tierce est interdite par la politique de contenu Microsoft Marketplace.

Ce blocage s'est produit à **cinq reprises** :

| # | Date | Titre soumis | Erreur |
|---|------|-------------|--------|
| 1 | 05/19/2026 | `Nextcloud Hub — Azure VM` | 100.7.1 (révision initiale) |
| 2 | 05/20/2026 | `Nextcloud Hub Cloud Edition — Azure Virtual Machines` | 100.1.1.1 |
| 3 | 05/20/2026 | `Nextcloud Hub Cloud Edition — Collaboration Platform for Azure` | 100.7.1 |
| 4 | 05/21/2026 | `Cotechnoe Nextcloud Hub — Self-Hosted Cloud Platform` | En cours |
| 5 | 05/21/2026 | `Cotechnoe Cloud Hub — Secure File Collaboration on Azure` | En cours |

### Diagnostic (05/21/2026)

Les rejets #4 et #5 ont confirmé que le problème n'est **pas uniquement** "Azure". Après suppression de toute référence à "Azure", les titres ont continué d'être rejetés avec l'erreur 100.7.1.

**Cause racine** : **"Nextcloud"** est une marque déposée de **Nextcloud GmbH**, enregistrée dans plusieurs juridictions. Son utilisation dans le titre d'un produit commercial sur Azure Marketplace sans accord explicite de Nextcloud GmbH peut violer la politique 100.7.1 (clause IP tierce). Vérifier les [Nextcloud Trademark Guidelines](https://nextcloud.com/trademarks/) avant soumission.

> **Note** : Le message d'erreur indique "Microsoft trademarked" mais c'est un template générique — la politique 100.7.1 couvre **toute propriété intellectuelle tierce**, pas uniquement les marques Microsoft.

**Constat** : l'utilisation de "Nextcloud" dans le titre peut déclencher la politique 100.7.1. Vérifier auprès de Nextcloud GmbH si l'utilisation commerciale du nom est permise (similaire aux cas de marques open source publiées sur Marketplace).

### Contraintes

- **Microsoft Marketplace Policy 100.7.1** : Interdit l'utilisation de toute propriété intellectuelle tierce sans autorisation — marques Microsoft (ex. "Azure") ET marques d'autres organisations.
- **Nextcloud GmbH Trademark** : "Nextcloud" est une marque déposée de Nextcloud GmbH. Son utilisation dans le nom d'un produit commercial nécessite une vérification des [Trademark Guidelines](https://nextcloud.com/trademarks/). Les termes descriptifs comme "cloud", "hub", "collaboration" sont génériques.
- **Règle 100.1.1.1** : Pour un logiciel repackagé, le nom de l'éditeur ("Cotechnoe") doit apparaître dans le titre.

---

## ✅ Décision

### Titre retenu

> **`Cotechnoe Cloud Hub — Secure File Collaboration on Azure`**

### Justification

| Critère | Explication |
|---------|-------------|
| Conformité marque | Évite le terme "Nextcloud" dans le titre ; utilise des termes génériques : "Cloud Hub", "Collaboration", "Secure", "Platform" |
| Éditeur visible | "Cotechnoe" satisfait la règle 100.1.1.1 (logiciel repackagé) |
| Web sémantique | "Linked Open Data" positionne clairement dans l'écosystème RDF/SPARQL/LOD |
| Différenciation | "Secure File Collaboration" décrit l'usage final ; "Cotechnoe" identifie le publisher |
| Concision | 47 caractères, lisible dans les listes de résultats Marketplace |

### Règle générale à retenir

| ❌ Interdit | ✅ Autorisé |
|------------|------------|
| `... Azure ...` / `... for Azure` | Termes descriptifs génériques (Wiki, Platform, Data) |
| `Nextcloud Hub ...` | Nom de l'éditeur (Cotechnoe) |
| `... Collaboration ...` | Termes descriptifs génériques |
| `Cloud Hub` / `File Sharing` (variantes) | Secure Collaboration, Self-Hosted |

---

## 📋 Implémentation

**Chemin Partner Center** :  
`Marketplace offers → Cotechnoe Cloud Hub → Offer listing → Listing title`

**Valeur à saisir** : `Cotechnoe Cloud Hub — Secure File Collaboration on Azure`

**Action** : Modifier le champ, sauvegarder, republier l'offre.

---

## 📚 Références

- [Microsoft Marketplace General Listing and Offer Policies](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#100-general)
- [Azure Virtual Machine Certification Policies — 100.1.1.1](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#1001-vm-images)
- Rapport certification 05/19/2026 : `docs/Certification/2026-05-19-partner.pdf`
- Rapport certification 05/20/2026 : (screenshot joint dans Partner Center)
- Rapport certification 05/21/2026 : (screenshot joint dans Partner Center) — rejets #4 et #5
- [Wikimedia Foundation Trademark Policy](https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_Trademark_Policy)
- [Nextcloud Trademark Guidelines](https://nextcloud.com/trademarks/) — vérifier usage commercial autorisé
