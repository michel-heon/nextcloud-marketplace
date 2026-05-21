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

Le titre soumis était : **`Semantic MediaWiki Cloud Edition — Azure Virtual Machines`**

L'expression **"Azure Virtual Machines"** est une marque déposée de Microsoft. Son utilisation directe dans le titre d'une offre tierce est interdite par la politique de contenu Microsoft Marketplace.

Ce blocage s'est produit à **cinq reprises** :

| # | Date | Titre soumis | Erreur |
|---|------|-------------|--------|
| 1 | 05/19/2026 | `Semantic MediaWiki — Azure VM` | 100.7.1 |
| 2 | 05/20/2026 | `Semantic MediaWiki Cloud Edition — Azure Virtual Machines` | 100.1.1.1 |
| 3 | 05/20/2026 | `Semantic MediaWiki Cloud Edition — Wiki Platform for Azure` | 100.7.1 |
| 4 | 05/21/2026 | `Semantic MediaWiki Cloud — Linked Data Wiki Platform` | 100.7.1 |
| 5 | 05/21/2026 | `Semantic MediaWiki Cloud Edition — Linked Open Data Wiki Platform` | 100.7.1 |

### Diagnostic (05/21/2026)

Les rejets #4 et #5 ont confirmé que le problème n'est **pas uniquement** "Azure". Après suppression de toute référence à "Azure", les titres ont continué d'être rejetés avec l'erreur 100.7.1.

**Cause racine** : **"MediaWiki"** est une marque nominale (*wordmark*) enregistrée de la **Wikimedia Foundation**, listée officiellement sur [foundation.wikimedia.org/wiki/Wikimedia_trademarks](https://foundation.wikimedia.org/wiki/Wikimedia_trademarks). Son utilisation dans le titre d'un produit commercial sur Azure Marketplace sans licence de la Wikimedia Foundation viole la politique 100.7.1 (clause IP tierce).

> **Note** : Le message d'erreur indique "Microsoft trademarked" mais c'est un template générique — la politique 100.7.1 couvre **toute propriété intellectuelle tierce**, pas uniquement les marques Microsoft.

**Constat** : les 5 titres rejetés contenaient tous "MediaWiki". Une fois "Azure" retiré (rejets #4 et #5), le seul terme déclenchant 100.7.1 est "MediaWiki".

### Contraintes

- **Microsoft Marketplace Policy 100.7.1** : Interdit l'utilisation de toute propriété intellectuelle tierce sans autorisation — marques Microsoft (ex. "Azure") ET marques d'autres organisations.
- **Wikimedia Foundation Trademark** : "MediaWiki" est une marque nominale déposée de la Wikimedia Foundation. Son utilisation dans le nom d'un produit commercial nécessite une licence. L'abréviation "SMW" n'est pas une marque déposée autonome.
- **Règle 100.1.1.1** : Pour un logiciel repackagé, le nom de l'éditeur ("Cotechnoe") doit apparaître dans le titre.

---

## ✅ Décision

### Titre retenu

> **`Cotechnoe SMW — Linked Open Data Wiki Platform`**

### Justification

| Critère | Explication |
|---------|-------------|
| Conformité marque | Aucune marque tierce : "SMW" est une abréviation non déposée, "Linked Open Data", "Wiki", "Platform" sont des termes génériques |
| Éditeur visible | "Cotechnoe" satisfait la règle 100.1.1.1 (logiciel repackagé) |
| Web sémantique | "Linked Open Data" positionne clairement dans l'écosystème RDF/SPARQL/LOD |
| Différenciation | "Wiki Platform" décrit l'usage final ; "SMW" est reconnaissable par l'audience cible |
| Concision | 47 caractères, lisible dans les listes de résultats Marketplace |

### Règle générale à retenir

| ❌ Interdit | ✅ Autorisé |
|------------|------------|
| `... Azure ...` / `... for Azure` | Termes descriptifs génériques (Wiki, Platform, Data) |
| `Semantic MediaWiki ...` | Abréviation maison (SMW) |
| `... MediaWiki ...` | Nom de l'éditeur (Cotechnoe) |
| `Media-Wiki` / `MediaWiki` (variantes typographiques) | Linked Open Data, Knowledge Graph |

---

## 📋 Implémentation

**Chemin Partner Center** :  
`Marketplace offers → Semantic MediaWiki Cloud Edition → Offer listing → Listing title`

**Valeur à saisir** : `Cotechnoe SMW — Linked Open Data Wiki Platform`

**Action** : Modifier le champ, sauvegarder, republier l'offre.

---

## 📚 Références

- [Microsoft Marketplace General Listing and Offer Policies](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#100-general)
- [Azure Virtual Machine Certification Policies — 100.1.1.1](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#1001-vm-images)
- Rapport certification 05/19/2026 : `docs/Certification/2026-05-19-partner.pdf`
- Rapport certification 05/20/2026 : (screenshot joint dans Partner Center)
- Rapport certification 05/21/2026 : (screenshot joint dans Partner Center) — rejets #4 et #5
- [Wikimedia Foundation Trademark Policy](https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_Trademark_Policy)
- [Wikimedia Trademarks List](https://foundation.wikimedia.org/wiki/Wikimedia_trademarks) — "MediaWiki" wordmark confirmé
