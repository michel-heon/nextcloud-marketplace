---
adr: 801
title: "Stratégie de Documentation — Offre Azure Marketplace (utilisateur final)"
status: "accepted"
date: 2026-03-07
superseded_by: null
replaces: null
related_adrs: [800]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "biz"
  impact: "high"
  quality:
    - "usability"
    - "compliance"
    - "maintainability"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "azure"
    - "marketplace"
    - "mediawiki"

tags: ["documentation", "azure-marketplace", "user-guide", "wiki", "partner-center", "content-guidelines"]
stakeholders: ["@dev-team", "@architecture-team"]
effort: "medium"
---

# ADR 801: Stratégie de Documentation — Offre Azure Marketplace (utilisateur final)

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-03-07 |
| **Impact** | 🔴 Élevé (conditionne la certification et l'adoption Marketplace) |
| **Domaine** | BIZ / Documentation |
| **Réversibilité** | 🟡 Modérée |
| **Portée** | Tous les contenus publiés dans `vivo-azure-marketplace-docs` et `vivo-azure-marketplace-docs.wiki` |

**Sources Microsoft** :
- [Marketplace listing guidelines](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-criteria-content-validation)
- [VM offer listing best practices](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-offer-best-practices)
- [Plan a VM offer — support URLs](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-virtual-machines#customer-support)
- [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/)
- [GTM Best Practices — Offer Listing & Campaign Tracking](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/gtm-best-practices)
- [Microsoft Marketplace GTM Toolkit (badges, co-branded assets, pitch deck)](https://partner.microsoft.com/en-US/asset/collection/microsoft-marketplace-gtm-toolkit#/)
- [Marketplace Best Practices Guide (PDF)](https://aka.ms/marketplacebestpracticesguide)

---

## 🎯 Contexte

L'offre SMW Knowledge Base est publiée sur Azure Marketplace à destination des **universités et centres de recherche** qui déploient la VM directement depuis le portail Azure. Ces utilisateurs :

- **ne sont pas des développeurs** du projet smw-marketplace ;
- n'ont pas accès au dépôt `michel-heon/smw-marketplace` ;
- attendent une documentation **opérationnelle, en anglais**, axée sur la configuration et l'utilisation de MediaWiki ;
- peuvent être des administrateurs systèmes, des responsables de plateformes de recherche, ou des informaticiens institutionnels.

La documentation publiée est référencée **directement dans Partner Center** (champ *Support URL* et *Learn More URL*). Microsoft vérifie que ces URLs sont accessibles, pertinentes, et conformes aux directives de contenu lors de la certification de l'offre.

Deux dépôts GitHub constituent la documentation publique :

| Dépôt | Rôle | URL publique |
|-------|------|-------------|
| `Cotechnoe/server-azure-marketplace-docs` | README et page d'accueil documentation | `github.com/Cotechnoe/server-azure-marketplace-docs` |
| `Cotechnoe/server-azure-marketplace-docs.wiki` | Pages de documentation détaillées | `github.com/Cotechnoe/server-azure-marketplace-docs/wiki` |

**Problème principal :** Sans une politique de contenu explicite, il y a un risque de glissement vers une documentation orientée *développement* (ADRs, Makefile, Packer, GitHub Actions) inadaptée aux clients Marketplace et possiblement non conforme aux directives Microsoft.

---

## 💡 Décision

**Nous adoptons une politique de documentation strictement orientée utilisateur final Marketplace**, structurée autour de deux dépôts à rôles distincts, rédigée en anglais, conforme aux directives de contenu Microsoft.

---

## 📐 Règles de Contenu

### Règle 1 — Audience unique : l'utilisateur Marketplace

Toute page wiki ou document doit répondre à la question :

> *"Est-ce qu'un responsable informatique d'une université qui vient de déployer MediaWiki depuis Azure Marketplace en a besoin ?"*

Si la réponse est non → le contenu n'appartient pas à ces dépôts.

**Est dans scope :**
- Connexion SSH à la VM déployée
- Vérification des services (nginx, Apache, MySQL)
- Configuration de MediaWiki (namespace, admin, langues)
- Certificat TLS (Let's Encrypt automatique, renouvellement)
- Chargement de données d'exemple
- Exploration de l'interface MediaWiki
- Résolution de problèmes courants de déploiement
- Contact support et ressources communautaires

**Hors scope :**
- Processus de build Packer
- Structure du dépôt `smw-marketplace`
- ADRs et décisions d'architecture interne
- Scripts de CI/CD, Makefile, pipeline de publication
- Détails d'implémentation ARM/Bicep (au-delà des paramètres exposés)
- Variables d'environnement internes (`config.make`, `packer-vars.json`)

### Règle 2 — Langue : English First, français disponible en traduction

L'offre Marketplace est accessible à l'échelle mondiale. La documentation suit une politique **English First** :

- **L'anglais est la langue canonique.** Chaque page wiki est d'abord rédigée en anglais. C'est la version de référence ; elle fait foi en cas de divergence.
- **Le français est offert en traduction dérivée.** Une version française peut être fournie pour chaque page, produite à partir de la version anglaise (et non co-rédigée indépendamment).
- **Les deux versions sont maintenues en tandem.** Toute modification apportée à une page anglaise doit être répercutée sur sa traduction française avant la prochaine publication Marketplace.
- Les commentaires de commit et les ADRs internes peuvent rester en français.

### Règle 3 — Ton et style Microsoft

Conforme au [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/) :

| Principe | Application concrète |
|----------|---------------------|
| **Friendly and conversational** | Vouvoiement évité → "you", phrases courtes |
| **Action-oriented** | Titres en verbe d'action : *Connect to the VM*, *Configure MediaWiki* |
| **Task-based** | Chaque page = une tâche utilisateur complète |
| **Show, don't just tell** | Exemples de commandes avec output attendu |
| **Progressive disclosure** | Cas courant en premier, cas avancés en fin de page |

Éviter :
- Le jargon interne au projet (`first-boot`, `provisioner`, `packer`)
- Les acronymes non définis lors de leur première apparition
- Les références aux fichiers sources du dépôt développeur

### Règle 4 — Structure des pages wiki

Chaque page doit suivre ce modèle :

```
# [Titre — verbe d'action ou sujet concret]

Brève introduction (1-2 phrases) : ce que l'utilisateur va accomplir.

---

## Prerequisites  (si nécessaire)
## Step 1 — [Action]
## Step 2 — [Action]
## Verify
## Troubleshooting  (optionnel, pour les cas courants liés à cette tâche)
```

### Règle 5 — Pas de liens vers le dépôt développeur

Ne pas référencer :
- `github.com/michel-heon/smw-marketplace`
- Des fichiers spécifiques du dépôt source (`.bicep`, `Makefile`, scripts Packer)

Les seules références externes autorisées :
- Documentation officielle MediaWiki/SMW (`www.mediawiki.org/wiki/Semantic_MediaWiki`)
- SMW Project (`www.semantic-mediawiki.org`)
- Documentation Azure (`learn.microsoft.com/azure`)
- Issues GitHub sur `Cotechnoe/server-azure-marketplace-docs` (support utilisateur)

### Règle 6 — Gestion des traductions (English First)

**Principe** : l'anglais est rédigé en premier, le français est généré à partir de l'anglais — jamais l'inverse.

**Convention de nommage des fichiers traduits :**

| Fichier anglais (canonique) | Fichier français (dérivé) |
|-----------------------------|--------------------------|
| `Deploying-from-Marketplace.md` | `Deploying-from-Marketplace-fr.md` |
| `Configuring-MediaWiki.md` | `Configuring-MediaWiki-fr.md` |
| `HTTPS-TLS-Certificate.md` | `HTTPS-TLS-Certificate-fr.md` |
| *(idem pour toute nouvelle page)* | *(suffixe `-fr` systématique)* |

**Workflow de traduction :**

1. Rédiger et valider la page en anglais.
2. Générer la traduction française (`-fr`) à partir de la page anglaise finalisée.
3. Insérer le lien de navigation bidirectionnel sous le H1 de chaque version :
   - Dans la page EN : `> 🇫🇷 Cette page est également disponible en français : [[Page Name fr]]`
   - Dans la page FR : `> 🇬🇧 This page is also available in English: [[Page Name]]`
4. Référencer les deux versions depuis `Home.md` (section *Available languages*).
5. Lors d'une mise à jour, modifier d'abord la version anglaise, puis mettre à jour la version française.

**Critères de qualité de la traduction française :**
- Traduire les titres de sections en français.
- Conserver en anglais les noms de commandes, paramètres, chemins de fichiers et extraits de code.
- Adapter les URLs Microsoft vers leur variante `/fr-fr/` quand elle existe.
- Utiliser le point décimal dans les expressions numériques du code, la virgule dans le texte narratif français.

---

### Règle 7 — Campaign Tracking : Paramètres UTM dans les Liens vers le Listing

**Principe** : Tout lien vers le listing Azure Marketplace **inclus dans la documentation** (README, pages wiki, emails de support) doit intégrer des paramètres de suivi.

**Raison** : Microsoft Marketplace fournit un dashboard [Insights](https://partner.microsoft.com/dashboard/insights/analytics/overview) qui trace le trafic entrant uniquement si les paramètres sont présents.

**Format canonique du lien tracké :**

```
https://azuremarketplace.microsoft.com/en-US/marketplace/apps/cotechnoe.smw-knowledge-base
  ?ocid=<id>&utm_source=<source>&utm_medium=<medium>&utm_campaign=<campaign>
```

**Tableau des paramètres obligatoires par contexte :**

| Contexte | `ocid` | `utm_source` | `utm_medium` | `utm_campaign` |
|----------|--------|-------------|-------------|---------------|
| Badge README.md (GitHub) | `smw_github_readme` | `github` | `referral` | `docs` |
| Page wiki Home.md | `smw_wiki_home` | `wiki` | `referral` | `docs` |
| Email support | `smw_support_email` | `email` | `email` | `support` |
| Post LinkedIn | `smw_linkedin_launch` | `linkedin` | `social` | `v1_launch` |

> **Règle** : Les pages wiki EN et FR doivent partager le **même** `ocid` — ne pas créer un ID par langue.

---

### Règle 8 — Assets Marketing Post-Publication (GTM Toolkit)

**Principe** : Utiliser **exclusivement** les ressources officielles du [GTM Toolkit Microsoft](https://partner.microsoft.com/en-US/asset/collection/microsoft-marketplace-gtm-toolkit#/) pour promouvoir la disponibilité de l'offre sur Marketplace.

**Assets à déployer après le premier Go Live :**

| Asset | Emplacement cible | Règle |
|-------|------------------|-------|
| **Badge "Available on Microsoft Marketplace"** | `README.md` du dépôt `Cotechnoe/server-azure-marketplace-docs` | Obligatoire — utiliser le badge officiel, pas un badge custom |
| **Co-branded social assets** | Posts LinkedIn lors du lancement ou d'une mise à jour majeure | Uniquement les visuels du GTM Toolkit (pas d'assets non co-brandés) |
| **Co-branded pitch deck** | À fournir à des partenaires ou lors de démonstrations institutionnelles | Personnaliser uniquement les zones dédiées partenaire |

**Règle Trademark** : Respecter les [Microsoft Trademark and Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general.aspx) pour tout contenu co-brandé. Ne jamais modifier les logos Microsoft dans les assets.

**AI listing optimization** : Avant chaque publication d'une nouvelle version, utiliser l'outil [App Advisor](https://www.microsoft.com/en-us/software-development-companies/app-advisor/guidance/my-results?stage=grow&step=optimize-your-listing-with-personalized-recommendations) pour générer des recommandations personnalisées d'amélioration du listing.

---

## 📁 Rôle des Dépôts

### `Cotechnoe/server-azure-marketplace-docs`

**Rôle** : Page d'accueil et index de la documentation.

Contenu autorisé :
- `README.md` : présentation de l'offre, tableau vers les pages wiki, badge de version
- `docs/` : guides longs en format Markdown si dépassant le format wiki (ex. guides détaillés de configuration institutionnelle)

Référencé dans Partner Center comme **Learn More URL** ou **Documentation URL**.

### `Cotechnoe/server-azure-marketplace-docs.wiki`

**Rôle** : Documentation opérationnelle page par page.

Structure cible des pages wiki :

| Page (EN — canonique) | Page (FR — traduction) | Description |
|-----------------------|------------------------|-------------|
| `Home` | `Home-fr` | Index navigation, Quick Start, architecture simplifiée |
| `SSH-Connection` | `SSH-Connection-fr` | Connexion SSH depuis Windows, Linux, macOS |
| `Post-Deployment-Verification` | `Post-Deployment-Verification-fr` | Vérifier que MediaWiki est opérationnel |
| `HTTPS-TLS-Certificate` | `HTTPS-TLS-Certificate-fr` | Certificat Let's Encrypt, renouvellement, cert personnalisé |
| `Configuring-MediaWiki` | `Configuring-MediaWiki-fr` | Namespace, admin, langues, paramètres runtime |
| `Deploying-from-Marketplace` | `Deploying-from-Marketplace-fr` | Déploiement depuis l'assistant Marketplace |
| `Loading-Sample-Data` | `Loading-Sample-Data-fr` | Charger le dataset d'exemple MediaWiki |
| `Exploring-MediaWiki` | `Exploring-MediaWiki-fr` | Navigation interface, recherche, profils, Site Admin |
| `Troubleshooting` | `Troubleshooting-fr` | Erreurs de déploiement et de runtime fréquentes |
| `Support` | `Support-fr` | Contacts publisher, communauté MediaWiki, Azure support |

> **Note :** Chaque page (EN et FR) comporte un lien de navigation en haut de page vers son homologue dans l'autre langue, inséré en blockquote sous le titre H1 :
> - Page EN → `> 🇫🇷 Cette page est également disponible en français : [[Page fr]]`
> - Page FR → `> 🇬🇧 This page is also available in English: [[Page]]`
>
> `Home.md` contient en outre une section *Available languages* qui liste l'ensemble des pages disponibles en français.

Référencé dans Partner Center comme **Support URL** (obligatoire, vérifié lors de la certification).

---

## 🔄 Processus de Mise à Jour

### Déclencheurs de mise à jour obligatoire

| Événement | Pages à mettre à jour |
|-----------|----------------------|
| Nouvelle version image (ex. 1.0.11) | `Home` (badge version), `Post-Deployment-Verification` |
| Nouveau paramètre ARM | `Home` (tableau paramètres), page concernée |
| Changement comportement TLS | `HTTPS-TLS-Certificate`, `Troubleshooting` |
| Nouvelle langue supportée | `Configuring-MediaWiki` |
| Problème récurrent signalé (Issue) | `Troubleshooting` |

### Check-list avant publication d'une nouvelle version Marketplace

**Contenu anglais (canonique) :**
- [ ] Badge version dans `README.md` mis à jour
- [ ] Section Release Notes dans `README.md` mise à jour
- [ ] Toutes les commandes testées sur l'image courante
- [ ] Aucune référence au dépôt développeur (`michel-heon/smw-marketplace`)
- [ ] Aucune commande de build Packer ou make dans les pages wiki
- [ ] Support URL vérifiée accessible depuis un navigateur incognito
- [ ] `Support.md` contient l'email publisher actuel
- [ ] Badge "Available on Microsoft Marketplace" présent dans `README.md` (asset officiel GTM Toolkit)
- [ ] Liens vers le listing Marketplace incluant les paramètres OCID et UTM (Règle 7)

**Traductions françaises :**
- [ ] Chaque page anglaise modifiée depuis la dernière publication a sa version `-fr` mise à jour
- [ ] Les noms de commandes, paramètres et extraits de code sont identiques dans EN et FR
- [ ] Chaque page EN contient le lien `🇫🇷` vers sa version FR sous le H1
- [ ] Chaque page FR contient le lien `🇬🇧` vers sa version EN sous le H1
- [ ] `Home.md` section *Available languages* liste toutes les pages FR disponibles

---

## 🚫 Anti-patterns à Éviter

Ces contenus ont été observés ou sont à risque dans des itérations précédentes :

| Anti-pattern | Problème | Correction |
|-------------|----------|-----------|
| "See `packer/scripts/server-first-boot.sh`" | Lien vers dépôt développeur | Décrire le comportement, pas l'implémentation |
| "Run `make packer-build`" | Commande développeur | Hors scope — ne pas documenter |
| Mentionner ADR-700, ADR-300, etc. | Jargon interne | Remplacer par la description de l'effet observable |
| "Generated by `cloud-init customData`" | Détail d'implémentation | "Configured automatically during first boot" |
| Rédiger la page FR avant la page EN | Inversion de la langue canonique | Toujours finaliser EN en premier, puis générer FR |
| Page FR divergeant de EN (sections manquantes) | Confiance réduite pour les francophones | Synchroniser FR dès que EN est modifié |
| Page wiki vide ou avec TODO | Mauvaise expérience utilisateur | Ne pas publier une page incomplète |
| Liens vers le listing Marketplace sans OCID/UTM | Trafic non traçable dans le dashboard Insights | Ajouter `?ocid=...&utm_source=...` à tous les liens |
| Utiliser un badge custom "Available on Azure Marketplace" | Violation des Trademark Guidelines Microsoft | Utiliser uniquement les badges officiels du GTM Toolkit |

---

## Conséquences

**Positives :**
- Documentation conforme aux directives Microsoft → certification facilitée
- Expérience utilisateur cohérente avec les standards Azure Marketplace
- Séparation claire entre documentation interne (ADRs, guides) et documentation client
- Support URL valide et maintenu = exigence de certification satisfaite

**Contraintes acceptées :**
- La documentation utilisateur doit être maintenue séparément du code source
- Les changements techniques dans `smw-marketplace` impliquent une mise à jour des docs si l'expérience utilisateur change
- Pas de génération automatique de documentation depuis le code source (risque de fuite de contenu développeur)

**Non-décisions (hors scope de cet ADR) :**
- Localisation vers d'autres langues (allemand, espagnol, portugais…) — à évaluer en ADR distinct si la demande le justifie
- Documentation in-app MediaWiki (configuration via interface web)
