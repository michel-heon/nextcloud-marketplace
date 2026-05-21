---
adr: 802
title: "Sources Officielles Azure Marketplace — Référentiel Anti-Hallucination IA"
status: "accepted"
date: 2026-05-14
superseded_by: null
replaces: null
related_adrs: [2, 800, 801]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "biz"
  impact: "high"
  quality:
    - "reliability"
    - "compliance"
    - "maintainability"
    - "traceability"
  reversibility: "easy"
  scope: "strategic"
  tech_areas:
    - "azure"
    - "marketplace"
    - "partner-center"
    - "vm"
    - "packer"

tags: ["azure-marketplace", "anti-hallucination", "ia", "sources", "partner-center", "vm-offer", "mastering-marketplace", "référentiel", "documentation"]
stakeholders: ["@architecture-team", "@devops-team", "@dev-team"]
effort: "low"
---

# ADR-802 : Sources Officielles Azure Marketplace — Référentiel Anti-Hallucination IA

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-05-14 |
| **Stakeholders** | @architecture-team, @devops-team, @dev-team |
| **Impact** | 🔴 Élevé (prévient les erreurs de certification, de sécurité et de publication) |
| **Effort Implémentation** | 🟢 Faible |
| **Risque Technique** | 🟡 Moyen (hallucinations non détectées → rejet de certification) |
| **Complémentaire de** | ADR-002 (contrainte générale IA), ADR-800 (conformité publication), ADR-801 (documentation) |

---

## 🎯 Contexte & Problème

Les agents IA (GitHub Copilot, Claude, GPT, etc.) produisent régulièrement des informations
**factuellement incorrectes** sur le processus de publication Azure Marketplace :

- Noms de champs Partner Center erronés ou inventés
- Numéros de politique de certification inexacts
- Flux de publication dans le mauvais ordre
- Terminologie mélangée entre types d'offres (VM, SaaS, AMA)
- URLs de scripts de certification ou d'outils CLI périmées
- Contraintes techniques inventées (taille d'image, formats SAS URI, etc.)

**ADR-002** pose le principe général de non-hallucination. Le présent ADR le spécialise pour le
domaine **Azure Marketplace / Partner Center / VM Offer** en centralisant les sources
canoniques que tout agent IA DOIT consulter avant de produire du contenu dans ce domaine.

---

## 💡 Décision

**Tout agent IA travaillant sur ce projet doit, pour toute affirmation relative à Azure
Marketplace (processus, terminologie, contraintes techniques, certification), se référer
exclusivement aux sources listées dans cet ADR — et non à ses données d'entraînement.**

Les sources ci-dessous sont les références faisant foi. Elles priment sur tout autre contenu.

---

## 📚 Sources Primaires Canoniques

### Source 1 — Microsoft Learn : Partner Center Marketplace Offers

| Attribut | Valeur |
|----------|--------|
| **URL** | <https://learn.microsoft.com/fr-fr/partner-center/marketplace-offers/> |
| **Langue** | Français (fr-FR) — aussi disponible en `en-US` |
| **Éditeur** | Microsoft (documentation officielle) |
| **Périmètre** | Création de compte, création d'offre, vente, paiements, API |
| **Mise à jour** | Continue — vérifier la date de révision de chaque page |

**Sous-pages critiques pour ce projet :**

| Page | URL | Usage |
|------|-----|-------|
| Vue d'ensemble Marketplace | `/overview` | Définitions et types d'offres |
| Offres VM | `/marketplace-virtual-machines` | Spécifications techniques VM |
| Politiques de certification | `https://learn.microsoft.com/fr-fr/legal/marketplace/certification-policies` | Sections 100, 200, 200.5 |
| Image depuis base approuvée | `/azure-vm-use-approved-base` | Contraintes OS de base |
| FAQ Certification VM | `/azure-vm-certification-faq` | Questions communes rejet certification |
| Critères de listing | `/marketplace-criteria-content-validation` | Titre, description, logo |
| API d'ingestion produit | `/product-ingestion-api` | API Partner Center v2 |
| Permissions Compute Gallery | `https://aka.ms/ComputeGalleryPermissions` | Rôles SP requis |

---

### Source 2 — Mastering the Marketplace (Microsoft GitHub)

| Attribut | Valeur |
|----------|--------|
| **URL** | <https://microsoft.github.io/Mastering-the-Marketplace/> |
| **Dépôt GitHub** | <https://github.com/microsoft/Mastering-the-Marketplace> |
| **Version** | v3.0.0 (au 2026-05-14) |
| **Éditeur** | Microsoft (contenu pédagogique officiel) |
| **Périmètre** | Vidéos, labs, démos pas-à-pas pour toutes les offres Marketplace |

**Modules spécifiques VM Offer (prioritaires pour ce projet) :**

| # | Module | URL | Contenu |
|---|--------|-----|---------|
| 1 | Vue d'ensemble des offres VM | `/vm/#creating-virtual-machine-offers-overview` | Processus de bout en bout |
| 2 | Partner Center pour VMs | `/vm/#partner-center-for-vms-overview` | Plans, CRM, pricing |
| 3 | Créer et personnaliser une VM | `/vm/#creating-and-customizing-a-vm-demo` | Installation logiciel |
| 4 | Généraliser et capturer | `/vm/#generalizing-and-capturing-a-vm-image-overview` | waagent, sysprep |
| 5 | Publier avec Partner Center | `/vm/#publish-your-vm-offer-with-partner-center-demo` | Plans, images, publication |
| 6 | Sécuriser la VM | `/vm/#securing-your-virtual-machine` | Hardening avant certification |
| 7 | Packer – vue d'ensemble | `/vm/#vm-automation-with-packer-overview` | Intégration Packer/Marketplace |
| 8 | Packer – démo | `/vm/#vm-automation-with-packer-demo` | Build automatisé avec Packer |
| 9 | Processus de certification | `/vm/#the-virtual-machine-offer-certification-process` | Causes communes d'échec |
| 10 | Outils de test VM | `/vm/#virtual-machine-test-tools-for-marketplace-demo` | AMAT (Azure Marketplace Assessment Tool) |
| 11 | Sécurité VM & containers | `/vm/#securing-virtual-machines-and-containers-for-certification` | PDF + vidéo certification |
| 12 | Déprécier / restaurer images | `/vm/#deprecating-and-restoring-virtual-machine-images` | Cycle de vie images |

**Autres modules utiles :**

| Module | URL | Pertinence |
|--------|-----|------------|
| Choisir son type d'offre | `/biz/select-offer-type` | Confirmer que VM est le bon choix |
| Partner Center général | `/partner-center/pc-general` | Navigation portal |
| Créer des offres | `/partner-center/pc-create-offers` | Étapes de création |
| Facturation flexible | `/partner-center/pc-flex-billing` | Modèles de prix |
| Offres privées | `/partner-center/private-offers` | Plans privés B2B |

---

### Source 3 — GTM : Best Practices Marketing et Go-To-Market Toolkit

| Attribut | Valeur |
|----------|--------|
| **URL principale** | <https://learn.microsoft.com/en-us/partner-center/marketplace-offers/gtm-best-practices> |
| **GTM Toolkit** | <https://partner.microsoft.com/en-US/asset/collection/microsoft-marketplace-gtm-toolkit#/> |
| **Best Practices Guide** | <https://aka.ms/marketplacebestpracticesguide> |
| **Éditeur** | Microsoft (documentation officielle + ressources partenaires) |
| **Périmètre** | Marketing post-publication, campagnes, listing optimization, co-branding |
| **Mise à jour** | Collection GTM Toolkit mise à jour le 2026-02-26 |

**Ressources incluses dans le GTM Toolkit (7 assets) :**

| Asset | Contenu | Téléchargement |
|-------|---------|---------------|
| **Available on Microsoft Marketplace badges** | Badges PNG/SVG pour promouvoir la disponibilité sur Marketplace | `available-on-microsoft-marketplace-badges.zip` (221.9 KB) |
| **Co-branded social assets** | Visuels pour LinkedIn, Twitter, Facebook co-brandés Microsoft+Partner | `microsoft-marketplace-co-branded-social-assets.zip` (41.3 MB) |
| **Co-branded pitch deck** | Présentation PowerPoint L100 sur les avantages d'achat via Marketplace | `microsoft-marketplace-cobranded-pitchdeck.pptx` |
| **AI-powered listing optimization** | Outil d'analyse et d'amélioration du listing en quelques secondes | <https://www.microsoft.com/en-us/software-development-companies/app-advisor/> |
| **Marketplace documentation** | Documentation complète Partner Center | <https://learn.microsoft.com/en-us/partner-center/marketplace-offers/> |
| **Channel-led opportunities** | Ressources multiparty private offers | Collection dédiée |
| **Lead management** | Gestion des leads CRM générés par le Marketplace | <https://learn.microsoft.com/en-us/partner-center/marketplace-offers/commercial-marketplace-get-customer-leads> |

**Bonnes pratiques de listing (source : `gtm-best-practices`) :**

| Élément | Recommandation Microsoft |
|---------|------------------------|
| **Nom de l'offre** | Titre clair incluant les mots-clés de recherche clients |
| **Description** | Proposition de valeur dans les 2-3 premières phrases (utilisées dans les résultats de recherche) |
| **Logo** | PNG 216×216 à 350×350 px (obligatoire pour la page de détails) |
| **Logo search** | 48×48 px — généré automatiquement par Partner Center depuis le grand logo |
| **Documents "Learn more"** | PDF éducatifs (livres blancs, brochures, présentations) — éduquer, pas vendre |
| **Vidéos** | 60-90 secondes — faire du **client** le héros, pas l'éditeur |
| **Screenshots** | Max 5 × 1280×720 px — inclure les mots-clés dans les noms de fichiers |

**Campaign tracking — paramètres UTM :**

| Paramètre | Rôle | Exemple |
|-----------|------|---------|
| `ocid` | Identifiant unique de campagne (grouper les résultats) | `smw_newsletter_may2026` |
| `utm_source` | Source du trafic | `newsletter`, `linkedin`, `website` |
| `utm_medium` | Type de lien | `email`, `cpc`, `social` |
| `utm_campaign` | Campagne ou promotion | `spring_launch`, `v1_release` |
| `utm_term` | Mots-clés payants ciblés | `semantic-wiki` |
| `utm_content` | Élément cliqué (A/B testing) | `header_button`, `cta_banner` |

Exemple d'URL trackée vers le listing SMW :
```
https://azuremarketplace.microsoft.com/en-US/marketplace/apps/cotechnoe.smw-knowledge-base
  ?ocid=smw_newsletter&utm_source=newsletter&utm_medium=email&utm_campaign=spring_launch
```

Résultats consultables dans l'[Insights workspace](https://partner.microsoft.com/dashboard/insights/analytics/overview) et le [Referrals workspace](https://partner.microsoft.com/dashboard/v2/referrals/v3/leads/marketplace) de Partner Center.

---

## 🗺️ Processus de Publication VM — Vue Canonique

> Source : Mastering the Marketplace, module 1 + Microsoft Learn `/marketplace-virtual-machines`

```
┌─────────────────────────────────────────────────────────────────────┐
│  ÉTAPE 1 : Prérequis                                                │
│  ├── Compte Partner Center inscrit au programme Commercial Marketplace
│  ├── MPN ID (Microsoft Partner Network)                             │
│  ├── Profil paiement et taxe configuré                              │
│  └── Azure Compute Gallery dans le même tenant Entra               │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────────┐
│  ÉTAPE 2 : Construire l'image VM                                    │
│  ├── OS de base : image endorsée Azure (Ubuntu 22.04 LTS ✅)        │
│  ├── Installer le logiciel applicatif (Packer provisioners)         │
│  ├── Généraliser : waagent -deprovision+user (Linux)                │
│  ├── Capturer dans Azure Compute Gallery (versionnée)               │
│  └── Vérifier : aucun secret, SSH activé, hv_netvsc chargé         │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────────┐
│  ÉTAPE 3 : Créer l'offre dans Partner Center                        │
│  ├── Offer setup : Offer ID (immuable), Alias, Publisher ID         │
│  ├── Properties : catégories, industries, version légale (BYOL)     │
│  ├── Offer listing : titre ≤200 chars, summary ≤100, description    │
│  │   logos (216×216, 1280×720), screenshots (1280×720, ≤5)          │
│  ├── Plans & Pricing : nom du plan, modèle de prix (BYOL/PAYG)      │
│  ├── Technical configuration : référence image Compute Gallery      │
│  │   (abonnement, RG, gallery, image definition, version)           │
│  └── Preview audience : abonnements Azure autorisés pour test       │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────────┐
│  ÉTAPE 4 : Certification automatisée Microsoft                      │
│  ├── Tests politiques 100 (contenu listing)                         │
│  ├── Tests politiques 200 (VM technique)                            │
│  │   ├── 200.3 : Image requirements (taille, format, généralisation)│
│  │   ├── 200.3.3 : Linux-specific (SSH, swap, hv_netvsc)            │
│  │   ├── 200.4 : Generalization (waagent déprovisionné)             │
│  │   └── 200.5 : Security (patches, pas de CVE critiques, TLS)      │
│  └── Résultat : Approuvé → Live / Rejeté → rapport d'erreurs        │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────────┐
│  ÉTAPE 5 : Publication Live                                         │
│  ├── Délai : 24-72h après approbation certification                 │
│  ├── Disponible sur Azure Marketplace et portail Azure              │
│  └── Mise à jour : nouveau build Packer → nouvelle version gallery  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📖 Vocabulaire Canonique Marketplace

> L'agent IA NE DOIT PAS inventer ou paraphraser ces termes. Utiliser la terminologie exacte.

| Terme officiel | Définition | Ne pas confondre avec |
|----------------|------------|-----------------------|
| **Offer ID** | Identifiant unique de l'offre — max 50 chars, minuscules + tirets, **immuable** après création | Alias de l'offre (interne) |
| **Publisher ID** | Identifiant de l'éditeur dans Partner Center (ex. `cotechnoe`) | Tenant ID Entra |
| **Plan** | Sous-unité d'une offre avec configuration technique et prix propres | Version d'image |
| **Technical Configuration** | Section Partner Center liant un Plan à une image Compute Gallery | Image Definition |
| **SAS URI** | URI de Signature d'Accès Partagé — ancienne méthode d'upload image (remplacée par Compute Gallery pour les nouvelles offres) | URL publique |
| **Azure Compute Gallery** | Service Azure stockant des images VM versionnées et répliquées | Azure Container Registry |
| **Image Definition** | Objet galerie décrivant l'OS, l'architecture et le type de VM (Gen1/Gen2) | Image Version |
| **Image Version** | Version concrète d'une Image Definition (ex. `6.0.1.20260514`) | Tag Git |
| **waagent** | Azure Linux Agent — doit être présent et déprovisionné (`-deprovision+user`) | cloud-init |
| **hv_netvsc** | Module noyau Linux requis pour la connectivité réseau Azure | virtio-net |
| **Generalization** | Processus supprimant les informations machine-spécifiques avant capture | Sysprep (Windows) |
| **BYOL** | Bring Your Own License — modèle de licence pour logiciel open source | Free tier |
| **PAYG** | Pay-As-You-Go — facturation à l'usage via Marketplace | BYOL |
| **Certification Policies** | Document Microsoft définissant les exigences de certification (sections 100–900) | Partner Center Docs |
| **Preview Audience** | Liste d'abonnements Azure autorisés à voir l'offre avant publication | Beta testers |
| **Commercial Marketplace** | Programme Partner Center permettant de publier des offres transactables | AppSource |
| **AMAT** | Azure Marketplace Assessment Tool — outil de test local avant certification | Pester, InSpec |
| **GTM Toolkit** | Collection officielle Microsoft de ressources post-publication (badges, social assets, pitch deck) — à accéder via `aka.ms/marketplacegtmltoolkit` | Matériaux marketing personnalisés |
| **OCID** | Identifiant de campagne Marketplace — paramètre query `?ocid=` à ajouter aux liens vers le listing pour tracer l'origine du trafic | UTM campaign ID |
| **UTM parameters** | Tags `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content` — standards Google Analytics pour mesurer l'efficacité des campagnes marketing | OCID (complémentaires, non substituts) |
| **Marketplace Insights** | Dashboard Partner Center mesurant le trafic, les conversions et l'engagement sur le listing — URL : `partner.microsoft.com/dashboard/insights/analytics/overview` | Azure Monitor |
| **Co-branded assets** | Visuels LinkedIn/Twitter/Facebook co-brandés Microsoft+Partner fournis dans le GTM Toolkit — à utiliser pour promouvoir la disponibilité sur Marketplace | Assets génériques |
| **Available on Marketplace badge** | Badge officiel PNG/SVG certifié Microsoft — doit remplacer tout logo maison pour promouvoir la disponibilité sur Marketplace | Logo créé par l'éditeur |

---

## 🚫 Contraintes pour l'Agent IA

En application d'**ADR-002** (contrainte générale de non-hallucination), les règles suivantes
s'appliquent spécifiquement au domaine Marketplace :

### Ce que l'agent DOIT faire

- ✅ Consulter les URLs de la section "Sources Primaires" avant de répondre à une question Marketplace
- ✅ Citer explicitement la section de politique de certification (ex. `§200.3.3`) quand il mentionne une exigence technique
- ✅ Utiliser le vocabulaire canonique du tableau ci-dessus tel quel
- ✅ Indiquer `[SOURCE REQUISE]` s'il ne peut pas vérifier une affirmation dans les sources listées
- ✅ Référencer cet ADR (ADR-802) dans tout ADR ou script traitant de Marketplace

### Ce que l'agent NE DOIT PAS faire

- ❌ Inventer des numéros de section de politique de certification non vérifiés
- ❌ Supposer qu'un champ Partner Center porte un certain nom sans vérification
- ❌ Mélanger les flux de publication SaaS, AMA et VM — ce sont des processus distincts
- ❌ Utiliser `SAS URI` comme méthode de référence d'image si l'offre utilise Compute Gallery
- ❌ Indiquer des délais de certification précis sans mention "variable selon la charge Microsoft"
- ❌ Supposer la compatibilité Gen1/Gen2 sans vérification dans la configuration de l'Image Definition

---

## 🔗 Ressources Complémentaires

| Ressource | URL | Usage |
|-----------|-----|-------|
| Labs pratiques Mastering Marketplace | <https://github.com/Azure/mtm-labs> | Exercices hands-on VM offer |
| Forum communauté Marketplace | <https://techcommunity.microsoft.com/category/mcpp/discussions/marketplace-forum> | Questions/réponses communautaires |
| Webinaires Marketplace (live + replay) | <https://aka.ms/MTMwebinars> | Formation continue |
| Contrat éditeur Microsoft | <https://learn.microsoft.com/fr-fr/legal/marketplace/msft-publisher-agreement> | Obligations légales éditeur |
| Disponibilité géographique et devises | `/marketplace-geo-availability-currencies` | Marchés disponibles |
| Guide API Marketplace | `/marketplace-apis-guide` | Automatisation via API |
| **GTM Best Practices** | <https://learn.microsoft.com/en-us/partner-center/marketplace-offers/gtm-best-practices> | Marketing listing, campaign tracking, listing best practices |
| **GTM Toolkit** | <https://partner.microsoft.com/en-US/asset/collection/microsoft-marketplace-gtm-toolkit#/> | Badges, co-branded assets, pitch deck, lead management |
| **Best Practices Guide (PDF)** | <https://aka.ms/marketplacebestpracticesguide> | Guide complet marketing et engagement client |

---

## 📐 Relation avec les Autres ADRs

| ADR | Titre | Relation |
|-----|-------|----------|
| [ADR-002](./002-META-agent-ia-non-hallucination.md) | Agent IA — Contrainte de Non-Hallucination | ADR-802 **spécialise** ADR-002 pour le domaine Marketplace |
| [ADR-800](./800-BIZ-publication-azure-marketplace-vm-offer.md) | Publication Offre VM | ADR-802 fournit les **sources** justifiant les décisions prises dans ADR-800 |
| [ADR-801](./801-BIZ-strategie-documentation-marketplace.md) | Stratégie Documentation Marketplace | ADR-802 référence les sources officielles que ADR-801 documente |
| [ADR-300](./300-SEC-securite-hardening-vm-certification.md) | Sécurité VM — Hardening | ADR-802 §200.5 confirme les exigences de sécurité tracées dans ADR-300 |
| [ADR-200](./200-INFRA-azure-infrastructure-vm-offer.md) | Infrastructure Azure VM | ADR-802 confirme l'architecture Compute Gallery par les sources officielles |

---

## ✅ Conséquences

### Positif

- Tout membre de l'équipe ou agent IA dispose d'un **point d'entrée unique et vérifié** pour les questions Marketplace
- Réduit le risque de rejet de certification par méconnaissance des politiques Microsoft
- Facilite l'onboarding de nouveaux agents IA sur le projet

### Négatif / Mitigation

- Les URLs Microsoft peuvent évoluer → **vérifier les liens tous les 3 mois** ou à chaque bump de version d'offre
- Le site Mastering the Marketplace est v3.0.0 (2026-05-14) — les modules vidéo peuvent devenir périmés avant les docs MS Learn
