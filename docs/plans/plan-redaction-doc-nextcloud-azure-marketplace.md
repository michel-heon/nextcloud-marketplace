# Plan de rédaction — Documentation `Cotechnoe/nextcloud-azure-marketplace-doc`

**Créé :** 2026-05-25  
**Projet :** Nextcloud Hub — Azure Marketplace VM  
**Dépôt cible :** `https://github.com/Cotechnoe/nextcloud-azure-marketplace-doc`  
**ADR de référence :** [`801-BIZ-strategie-documentation-marketplace.md`](../adr/801-BIZ-strategie-documentation-marketplace.md)  
**Dépôts inspirants :** `Cotechnoe/fuseki-azure-marketplace-docs`, `Cotechnoe/vivo-azure-marketplace-docs`

---

## 1. Objectif

Ce plan décrit l'ensemble des documents à rédiger pour le dépôt public
`Cotechnoe/nextcloud-azure-marketplace-doc`, qui constitue la documentation de l'offre
**Nextcloud Hub** sur Azure Marketplace, destinée aux administrateurs et équipes IT
des universités et centres de recherche.

Il ne couvre **pas** les ADRs ni la documentation interne du dépôt de build
`nextcloud-marketplace` — ceux-ci font l'objet du plan
`plan-adaptation-adrs-smw-vers-nextcloud.md`.

> ⚠️ **Sources officielles anti-hallucination** — toute affirmation sur les exigences
> Partner Center doit être vérifiable dans l'une de ces trois sources primaires :
> - [Partner Center Marketplace Offers](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/) — portail de référence pour la création d'offres
> - [Mastering the Marketplace — VM](https://microsoft.github.io/Mastering-the-Marketplace/vm) — cours vidéo + labs pour les offres VM
> - [Certification Policies §200 VM](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#200-virtual-machines) — politiques de certification officielles

### Public visé par la documentation

| Profil | Besoin |
|--------|--------|
| Administrateur système (université/centre de recherche) | Déployer la VM, vérifier les services, configurer Nextcloud |
| Responsable de plateforme de recherche | Gestion des utilisateurs, quotas, apps, intégration SSO |
| Informaticien institutionnel | TLS, sauvegardes, supervision, mise à jour |

### Politique de langue (ADR 801)

- **English First** : toute page est d'abord rédigée en anglais (version canonique).
- **Français** : traduction dérivée produite à partir de la version anglaise finalisée.
- Les deux versions sont maintenues en tandem (même numéro de commit de synchronisation).

---

## 2. Structure cible du dépôt

Inspirée des dépôts `fuseki-azure-marketplace-docs` et `vivo-azure-marketplace-docs` :

```
nextcloud-azure-marketplace-doc/
├── README.md                        # Index EN + Quick Start + tableau doc
├── README-fr.md                     # Traduction française du README
├── NOTICE.md                        # Crédits, attributions (Nextcloud AGPL-3.0)
├── LICENSE.md                       # Licence de la documentation (CC BY 4.0)
├── PRIVACY.md                       # Avis de confidentialité (RGPD)
├── Makefile                         # Automatisation (lint, preview, sync)
├── .gitignore
├── docs/
│   ├── vm-sizing-guide.md           # Tableau SKU Azure vs charge Nextcloud
│   ├── vm-sizing-guide-fr.md
│   ├── nextcloud-apps-guide.md      # Applications Nextcloud recommandées
│   ├── nextcloud-apps-guide-fr.md
│   ├── backup-restore.md            # Sauvegarde et restauration
│   ├── backup-restore-fr.md
│   ├── entra-id-sso.md              # SSO Microsoft Entra ID (SAML/OIDC)
│   ├── entra-id-sso-fr.md
│   └── monitoring.md                # Supervision et alertes Azure
│   └── monitoring-fr.md
└── wiki/                            # Copies sources des pages wiki (optionnel)
```

---

## 3. Phases de rédaction

### Phase 1 — Fondations du dépôt
**Objectif :** Rendre le dépôt opérationnel avec les fichiers de base et le
README principal. Ces documents sont requis avant que le dépôt soit référencé
dans Partner Center.

| # | Document | Langue | Priorité | Effort | Notes |
|---|----------|--------|----------|--------|-------|
| 1.1 | `README.md` | EN | 🔴 Critique | Modéré | Présentation offre, tableau doc, badge Marketplace, Quick Start 3 étapes |
| 1.2 | `README-fr.md` | FR | 🔴 Critique | Mineur | Traduction de 1.1 |
| 1.3 | `NOTICE.md` | EN | 🟡 Important | Mineur | Crédits Nextcloud GmbH (marque), mention licence AGPL-3.0 de l'app |
| 1.4 | `LICENSE.md` | EN | 🟡 Important | Mineur | CC BY 4.0 pour la documentation elle-même |
| 1.5 | `PRIVACY.md` | EN | 🟡 Important | Modéré | Données collectées par la VM, politique de rétention, contact DPO |
| 1.6 | `Makefile` | — | 🟢 Utile | Modéré | Cibles : `lint`, `preview`, `check-links`, `sync-fr` |

**Dépendances :** Aucune — peut démarrer immédiatement.  
**Critère de complétion :** Le dépôt est listable sur GitHub avec un README clair ; Partner Center peut y être référencé.

---

### Phase 2 — Pages wiki essentielles (flux de déploiement)
**Objectif :** Couvrir le parcours utilisateur principal : déploiement → connexion → 
vérification → configuration de base. Ces pages sont vérifiées par Microsoft lors
de la certification.

Ordre de rédaction = ordre du parcours utilisateur.

| # | Page wiki (EN) | Page wiki (FR) | Priorité | Effort | Description |
|---|----------------|----------------|----------|--------|-------------|
| 2.1 | `Home` | `Home-fr` | 🔴 Critique | Modéré | Index navigation, architecture simplifiée (1 VM, multi-services), Quick Start, liens pages |
| 2.2 | `Deploying-from-Marketplace` | `Deploying-from-Marketplace-fr` | 🔴 Critique | Modéré | Paramètres ARM : taille VM, région, user SSH, port 443 ; bouton Deploy |
| 2.3 | `SSH-Connection` | `SSH-Connection-fr` | 🔴 Critique | Mineur | Connexion SSH depuis Windows (PuTTY/Terminal), Linux, macOS |
| 2.4 | `Post-Deployment-Verification` | `Post-Deployment-Verification-fr` | 🔴 Critique | Modéré | Vérifier nginx, PHP-FPM, MariaDB, Redis ; accès HTTPS ; status `occ` |
| 2.5 | `HTTPS-TLS-Certificate` | `HTTPS-TLS-Certificate-fr` | 🔴 Critique | Modéré | Certificat Let's Encrypt auto, renouvellement certbot, cert personnalisé |
| 2.6 | `Configuring-Nextcloud` | `Configuring-Nextcloud-fr` | 🔴 Critique | Majeur | Wizard first-boot vs `occ maintenance:install`, admin, domaine de confiance, stockage |

**Dépendances :** Phase 1 (README doit être publié en premier).  
**Critère de complétion :** Un utilisateur peut déployer Nextcloud depuis zéro et accéder à l'interface HTTPS.

> **Référence certification :** [§200.2 Business Requirements](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#200-virtual-machines) — *« The App Description must match the application included in the VM and must have been tested for primary functionality after deployment »*. La page `Post-Deployment-Verification` remplit cette exigence.

---

### Phase 3 — Pages wiki d'exploration et de gestion courante
**Objectif :** Permettre à l'utilisateur d'exploiter et d'administrer Nextcloud
au quotidien.

| # | Page wiki (EN) | Page wiki (FR) | Priorité | Effort | Description |
|---|----------------|----------------|----------|--------|-------------|
| 3.1 | `Exploring-Nextcloud` | `Exploring-Nextcloud-fr` | 🟡 Important | Modéré | Navigation interface, Files, Talk, Calendar, Office Online, gestion utilisateurs |
| 3.2 | `Loading-Sample-Data` | `Loading-Sample-Data-fr` | 🟡 Important | Mineur | Upload fichiers d'exemple, partage, lien public — valide le déploiement |
| 3.3 | `Troubleshooting` | `Troubleshooting-fr` | 🟡 Important | Majeur | Top 10 problèmes post-déploiement : port 443, cert expiré, DB connexion, PHP-FPM |
| 3.4 | `Support` | `Support-fr` | 🟡 Important | Mineur | Issues GitHub, forum Nextcloud, support Azure, contact Cotechnoe |

**Dépendances :** Phase 2 complétée.  
**Critère de complétion :** L'utilisateur peut utiliser Nextcloud de façon autonome et trouver de l'aide.

---

### Phase 4 — Guides techniques approfondis (dossier `docs/`)
**Objectif :** Répondre aux besoins des administrateurs expérimentés et des
intégrations avancées. Moins urgents pour la certification initiale.

| # | Document | Langue | Priorité | Effort | Description |
|---|----------|--------|----------|--------|-------------|
| 4.1 | `docs/vm-sizing-guide.md` | EN+FR | 🟡 Important | Modéré | Tableau SKU (B2s, D2s_v3, D4s_v3, etc.) vs nb d'utilisateurs, stockage Nextcloud |
| 4.2 | `docs/nextcloud-apps-guide.md` | EN+FR | 🟡 Important | Modéré | Apps recommandées : Collabora Online, Talk, Calendar, Contacts, Two-Factor Auth |
| 4.3 | `docs/backup-restore.md` | EN+FR | 🟡 Important | Majeur | Sauvegarde des données (`/var/www/nextcloud/data`), dump MariaDB, Azure Backup |
| 4.4 | `docs/entra-id-sso.md` | EN+FR | 🟢 Utile | Majeur | Intégration SSO Entra ID (SAML 2.0 / OIDC) — app `user_saml` + configuration Nextcloud |
| 4.5 | `docs/monitoring.md` | EN+FR | 🟢 Utile | Modéré | Azure Monitor, alertes CPU/disk, logs nginx/PHP-FPM, intégration Prometheus |

**Dépendances :** Phase 2 et 3 doivent être publiées.  
**Critère de complétion :** Couverture complète des scénarios d'administration avancés.

---

### Phase 5 — Assets marketing et listing Partner Center
**Objectif :** Compléter le dossier de certification Marketplace et préparer le
lancement (Go Live).

| # | Livrable | Priorité | Effort | Description |
|---|----------|----------|--------|-------------|
| 5.1 | Description courte Marketplace (256 car. max) | 🔴 Critique | Mineur | EN + FR — accroche : « Deploy a fully configured Nextcloud Hub on Azure » |
| 5.2 | Description longue Marketplace (≤ 3000 car.) | 🔴 Critique | Modéré | EN + FR — features, use cases université/recherche, getting started |
| 5.3 | Notes de démarrage rapide Marketplace | 🔴 Critique | Mineur | Texte affiché pendant le déploiement ARM (≤ 500 car.) |
| 5.4 | Screenshots Marketplace (min. 2, max. 5) | 🟡 Important | Modéré | 1280×720 : interface web Nextcloud, tableau bord admin, HTTPS cert |
| 5.5 | Badge Azure Marketplace dans README.md | 🟡 Important | Mineur | Badge officiel GTM Toolkit avec paramètres UTM (ADR 801, Règle 7) |
| 5.6 | Release Notes (première version) | 🟢 Utile | Mineur | Modèle `vivo-azure-marketplace-docs` : new features, improvements, fixes |

**Dépendances :** Phase 1 complétée ; Phase 2 en cours ou terminée.  
**Critère de complétion :** Dossier Partner Center complet, apte à la soumission pour certification Microsoft.

> **Référence certification §100 General :**
> - [§100.2.1 Categories](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#100-general) — max 2 catégories ; description doit expliquer la pertinence de chaque catégorie
> - [§100.5 Offer information](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#100-general) — documentation doit être *« available, detailed, instructive, and current »* ; lien Privacy Policy obligatoire
> - [§100.4 Pricing and terms](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#100-general) — Terms and conditions requis
> - [VM Offer How-To Guide](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-virtual-machines) — guide officiel Partner Center pour les offres VM

---

## 4. Tableau de bord — Synthèse des livrables

| Phase | Livrables EN | Livrables FR | Priorité max | Effort total estimé |
|-------|:-----------:|:-----------:|:------------:|:--------------------|
| 1 — Fondations | 4 | 1 | 🔴 Critique | ~4 h |
| 2 — Wiki essentielles | 6 pages | 6 pages | 🔴 Critique | ~12 h |
| 3 — Wiki courante | 4 pages | 4 pages | 🟡 Important | ~8 h |
| 4 — Guides techniques | 5 docs | 5 docs | 🟡 Important | ~14 h |
| 5 — Assets Marketplace | 6 | — | 🔴 Critique | ~5 h |
| **Total** | **25** | **16** | — | **~43 h** |

---

## 5. Spécificités Nextcloud à traiter

Ces points distinguent la documentation Nextcloud de celle des autres offres
Cotechnoe (Fuseki, VIVO, SMW) et doivent être traités explicitement.

### 5.1 Architecture multi-services dans une seule VM
La VM déploie simultanément :
- **Nginx** (reverse proxy + TLS)
- **PHP-FPM 8.1+** (avec extensions : gd, curl, mbstring, xml, zip, intl, sodium, pdo_mysql, etc.)
- **MariaDB** (base de données Nextcloud intégrée)
- **Redis** (cache sessions et fichiers verrous — fortement recommandé)

Les guides de vérification (`Post-Deployment-Verification`) doivent couvrir les 4 services.

### 5.2 Wizard de première installation vs `occ`
Deux stratégies possibles — à documenter clairement :
- **Wizard web** : L'utilisateur complète l'installation via `https://<ip>/` au premier démarrage.
- **`occ maintenance:install`** : Pré-configuration automatisée par cloud-init, Nextcloud prêt à l'emploi.

La page `Configuring-Nextcloud` doit expliquer laquelle s'applique à l'image livrée.

### 5.3 Outil CLI `occ`
Central pour l'automatisation et l'administration. À documenter dans chaque guide où il est pertinent :
```bash
sudo -u www-data php /var/www/nextcloud/occ <commande>
```
Exemples : `status`, `maintenance:mode`, `user:list`, `app:install`, `db:convert-filecache-bigint`.

### 5.4 Marque Nextcloud (ADR 803)
- Respecter les [Nextcloud Trademark Guidelines](https://nextcloud.com/trademarks/).
- Utiliser « Nextcloud » (avec majuscule), pas « nextcloud », « Next Cloud » ni « NC ».
- Toujours mentionner « Nextcloud GmbH » comme détenteur de la marque dans `NOTICE.md`.
- Ne pas laisser entendre que Cotechnoe est affilié à Nextcloud GmbH.

### 5.5 Licence AGPL-3.0 de Nextcloud
Mentionner explicitement dans `NOTICE.md` et le README que :
- Le logiciel Nextcloud est distribué sous licence [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html).
- La documentation Cotechnoe (ce dépôt) est sous licence [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- L'image VM Cotechnoe est un packaging distinct — ne pas confondre les licences.

### 5.6 Versions Nextcloud
Nextcloud maintient deux branches (ex. NC 29 LTS + NC 30 stable). Documenter :
- Quelle version est embarquée dans l'image publiée.
- La politique de mise à jour (canal `stable`, `maintenance:update` via `occ`).
- Les notes de version dans le README (modèle VIVO : sections *New features*, *Improvements*, *Bug fixes*).

### 5.7 Stockage et quotas
Contrairement à Fuseki ou VIVO, Nextcloud est centré sur le stockage de fichiers.
Documenter dans `vm-sizing-guide.md` :
- Disque de données séparé recommandé (Azure Data Disk) vs disque OS.
- Chemin par défaut : `/var/www/nextcloud/data/`.
- Commande pour déplacer le dossier de données (`occ config:system:set datadirectory`).

---

## 6. Conventions de rédaction

Référence : ADR 801, Règles 3 et 4.

### 6.1 Structure de chaque page wiki

```markdown
# [Titre — verbe d'action ou sujet concret]

> 🇫🇷 Cette page est également disponible en français : [[Page-fr]]

Brève introduction (1-2 phrases) — ce que l'utilisateur va accomplir.

---

## Prerequisites
## Step 1 — [Action]
## Step 2 — [Action]
## Verify
## Troubleshooting   ← optionnel, pour les cas courants liés à cette tâche
```

### 6.2 Paramètres UTM dans les liens vers le listing (ADR 801, Règle 7)

```
https://azuremarketplace.microsoft.com/en-US/marketplace/apps/cotechnoe.nextcloud-hub
  ?ocid=nc_github_readme&utm_source=github&utm_medium=referral&utm_campaign=docs
```

| Contexte | `ocid` | `utm_source` | `utm_medium` |
|----------|--------|-------------|-------------|
| README.md | `nc_github_readme` | `github` | `referral` |
| Home.md wiki | `nc_wiki_home` | `wiki` | `referral` |
| Email support | `nc_support_email` | `email` | `email` |

### 6.3 Nommage des fichiers traduits

| Fichier EN (canonique) | Fichier FR (dérivé) |
|------------------------|---------------------|
| `Deploying-from-Marketplace.md` | `Deploying-from-Marketplace-fr.md` |
| `Configuring-Nextcloud.md` | `Configuring-Nextcloud-fr.md` |
| `docs/vm-sizing-guide.md` | `docs/vm-sizing-guide-fr.md` |

---

## 7. Critères de complétion globale

Le dépôt `Cotechnoe/nextcloud-azure-marketplace-doc` est considéré **prêt pour la
certification Partner Center** quand :

- [ ] `README.md` publié avec badge Marketplace et tableau wiki complet
- [ ] Phases 1 et 2 complétées (fondations + wiki essentielles)
- [ ] Toutes les pages wiki de Phase 2 ont leur traduction française
- [ ] Les URLs wiki sont référencées dans Partner Center (Learn More URL + Support URL)
- [ ] `NOTICE.md` mentionne la marque Nextcloud GmbH et la licence AGPL-3.0
- [ ] Aucune référence au dépôt développeur `nextcloud-marketplace` dans les pages publiques
- [ ] Le lien Support URL répond en HTTP 200 (vérifié par la pipeline Partner Center)

La documentation est considérée **complète** quand les Phases 3, 4 et 5 sont
également publiées.

---

## 8. Références

### Sources primaires officielles Microsoft (anti-hallucination)

| Source | URL | Usage |
|--------|-----|-------|
| **Partner Center — Marketplace Offers** | [learn.microsoft.com/…/marketplace-offers/](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/) | Portail principal : guide de création d'offres VM, listing, pricing, publishing |
| **Mastering the Marketplace** | [microsoft.github.io/Mastering-the-Marketplace/](https://microsoft.github.io/Mastering-the-Marketplace/) | Cours vidéo, labs interactifs, exemples — hub complet |
| **Mastering the Marketplace — VM** | […/vm](https://microsoft.github.io/Mastering-the-Marketplace/vm) | Section spécifique aux offres Virtual Machine |
| **Mastering the Marketplace — Partner Center** | […/partner-center/](https://microsoft.github.io/Mastering-the-Marketplace/partner-center/) | Utilisation du portail Partner Center, création et publication d'offres |
| **Certification Policies** | [learn.microsoft.com/…/certification-policies](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies) | Politiques complètes de certification (doc v1.67) |
| **Certification Policies §100 General** | […#100-general](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#100-general) | Exigences communes : title, description, categories, terms, privacy |
| **Certification Policies §200 Virtual Machines** | […#200-virtual-machines](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies#200-virtual-machines) | Exigences techniques et business spécifiques aux offres VM Linux |
| **VM Offer How-To (Partner Center)** | [learn.microsoft.com/…/marketplace-virtual-machines](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-virtual-machines) | Guide étape par étape pour publier une offre VM |

### Références internes

| Document | Lien |
|----------|------|
| ADR 801 — Stratégie documentation Marketplace | [`../adr/801-BIZ-strategie-documentation-marketplace.md`](../adr/801-BIZ-strategie-documentation-marketplace.md) |
| ADR 802 — Sources officielles Azure Marketplace | [`../adr/802-BIZ-sources-officielles-azure-marketplace.md`](../adr/802-BIZ-sources-officielles-azure-marketplace.md) |
| ADR 803 — Titre offre et conformité marque | [`../adr/803-BIZ-titre-offre-marketplace-conformite-marque.md`](../adr/803-BIZ-titre-offre-marketplace-conformite-marque.md) |
| Dépôt de référence — Fuseki docs | [`Cotechnoe/fuseki-azure-marketplace-docs`](https://github.com/Cotechnoe/fuseki-azure-marketplace-docs) |
| Dépôt de référence — VIVO docs | [`Cotechnoe/vivo-azure-marketplace-docs`](https://github.com/Cotechnoe/vivo-azure-marketplace-docs) |
| Nextcloud Trademark Guidelines | [`nextcloud.com/trademarks`](https://nextcloud.com/trademarks/) |
| Microsoft Writing Style Guide | [`learn.microsoft.com/style-guide`](https://learn.microsoft.com/en-us/style-guide/welcome/) |
| Partner Center Listing Guidelines | [`learn.microsoft.com/…/marketplace-criteria-content-validation`](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-criteria-content-validation) |
