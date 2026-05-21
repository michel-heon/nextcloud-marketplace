---
adr: 609
title: "Stratégie Version PHP — PHP 8.2 pour Nextcloud Hub 31"
status: "accepted"
date: 2026-04-04
classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "low"
  quality:
    - "maintainability"
    - "reliability"
    - "security"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "php"
    - "nextcloud"
    - "nginx"

tags: ["php-8.2", "nextcloud", "nextcloud-hub", "version-strategy"]
stakeholders: ["@dev-team", "@devops-team"]
effort: "low"
related_issues: []
related_adrs: [001, 200]
replaces: null
superseded_by: null
---

# ADR 609: Stratégie Version PHP — PHP 8.2 pour Nextcloud Hub 31

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-04-04 |
| **Impact** | 🟢 Faible (choix documenté dans la plage de compatibilité officielle) |
| **Domaine** | DevOps / Build |
| **Réversibilité** | 🟡 Modérée (changement de version PHP dans les scripts de provisioning) |
| **Portée** | Version PHP dans `packer/provisioners/install-php.sh` et configuration Apache/PHP-FPM |

## 🎯 Contexte

### Problème

Nextcloud Hub 31.x supporte une plage de versions PHP : **PHP 8.1 à PHP 8.4**.
Il faut choisir une version précise à installer dans l'image VM afin de garantir :
- Compatibilité totale avec Nextcloud Hub 31.x
- Disponibilité du paquet sur Ubuntu 22.04 LTS (via PPA `ondrej/php`)
- Stabilité et support à long terme

### Plage de compatibilité officielle

| Version PHP | Compatible Nextcloud 31.x | Statut |
|-------------|----------------------|------------------------------|--------|
| PHP 8.1 | ✅ Oui | ✅ Oui | Security fixes only (EOL Nov 2024) |
| **PHP 8.2** | ✅ Oui | ✅ Oui | **Active support (EOL Dec 2026)** ← Retenu |
| PHP 8.3 | ✅ Oui | ✅ Oui | Active support (EOL Dec 2027) |
| PHP 8.4 | ✅ Oui | ✅ Oui | Active support (EOL Dec 2028) |

Sources : [docs.nextcloud.com](https://docs.nextcloud.com/server/latest/admin_manual/installation/php_configuration.html)

## 💡 Décision

**Nous choisissons PHP 8.2** comme version PHP pour l'image VM nextcloud-marketplace.

### Justification

| Critère | PHP 8.1 | PHP 8.2 ✅ | PHP 8.3 | PHP 8.4 |
|---------|---------|------------|---------|---------|
| Compatibilité Nextcloud 31 | ✅ | ✅ | ✅ | ✅ |

| Support actif | ❌ EOL | ✅ Actif | ✅ Actif | ✅ Actif |
| Maturité (éviter bugs early-adopter) | ✅ | ✅ | ⚠️ Moins testé | ⚠️ Très récent |
| Disponible via ondrej/php PPA | ✅ | ✅ | ✅ | ✅ |
| **Retenu** | | **✅** | | |

PHP 8.2 offre le meilleur équilibre entre **support actif**, **maturité** et **compatibilité** avec l'ensemble du stack Nextcloud.

### Configuration retenue

```bash
# Installation via PPA ondrej/php sur Ubuntu 22.04 LTS
add-apt-repository ppa:ondrej/php
apt-get install -y php8.2 php8.2-fpm php8.2-mysql php8.2-xml \
  php8.2-mbstring php8.2-intl php8.2-curl php8.2-zip php8.2-gd
```

Extensions PHP requises par Nextcloud :
- `php8.2-mysql` — connexion MariaDB
- `php8.2-xml` — parsing XML
- `php8.2-mbstring` — support multibyte (unicode)
- `php8.2-intl` — internationalisation
- `php8.2-curl` — requêtes HTTP sortantes
- `php8.2-zip` — gestion archives (Composer)
- `php8.2-gd` — traitement images

## ⚖️ Conséquences

### ✅ Positives

- Compatibilité garantie avec Nextcloud Hub 31.x
- Support de sécurité actif jusqu'en décembre 2026 (horizon suffisant pour MVP)
- Version stable et bien testée par la communauté Nextcloud
- Packages disponibles sur Ubuntu 22.04 via PPA `ondrej/php`

### ⚠️ Négatives / Risques

| Risque | Impact | Probabilité | Mitigation |
|--------|--------|-------------|------------|
| EOL PHP 8.2 (déc. 2026) | 🟡 Moyen | Certain (long terme) | Mise à jour vers PHP 8.3 ou 8.4 dans une prochaine version image |
| Bug incompatibilité PHP 8.2 non détecté | 🟢 Faible | Faible | Tests de smoke post-déploiement |

## 🔄 Critères de Re-évaluation

**Déclencher une review si** :
- ⚠️ Nouvelle version majeure Nextcloud nécessitant PHP 8.3+
- ⚠️ EOL PHP 8.2 approchant (< 6 mois)
- ⚠️ Vulnérabilité critique PHP 8.2 sans patch

**Responsable Review** : @devops-team  
**Fréquence Review** : Tous les 6 mois

## 🔗 Références

- [Nextcloud — PHP requirements](https://docs.nextcloud.com/server/latest/admin_manual/installation/source_installation.html)
- [Nextcloud — Compatibility](https://docs.nextcloud.com/server/latest/admin_manual/)
- [PHP Supported Versions](https://www.php.net/supported-versions.php)
- [ondrej/php PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php)

## 📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-04-04 | @devops-team | Création ADR-609 | Choix version PHP pour image VM Nextcloud Marketplace |
