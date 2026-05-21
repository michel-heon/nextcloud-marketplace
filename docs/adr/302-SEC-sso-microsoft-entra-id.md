---
# 🤖 Machine-Readable Metadata (Frontmatter YAML)
adr: 302
title: "Authentification SSO via Microsoft Entra ID avec user_saml (SAML 2.0)"
status: "accepted"
date: 2025-07-12
superseded_by: null
replaces: null
related_adrs: [300]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "security"
  impact: "high"
  quality:
    - "security"
    - "reliability"
    - "maintainability"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "azure"
    - "nextcloud"
    - "saml"

tags: ["azure-marketplace", "sso", "entra-id", "saml", "authentication", "nextcloud", "user-saml"]
stakeholders: ["@architecture-team", "@dev-team"]
effort: "medium"
---

# ADR 302: Authentification SSO via Microsoft Entra ID avec user_saml (SAML 2.0)

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2025-07-12 |
| **Stakeholders** | @architecture-team, @dev-team, @security-team |
| **Impact** | 🔴 Élevé |
| **Effort Implémentation** | 🟡 Moyen |
| **Risque Technique** | 🟢 Faible |

---

## 🎯 Contexte & Problème

### Problème Principal

Nextcloud dispose d'un mécanisme SSO natif via l'application **user_saml**. Pour les clients de l'offre Azure Marketplace qui utilisent **Microsoft Entra ID** (anciennement Azure AD) comme fournisseur d'identité, il est nécessaire de configurer cette app pour déléguer l'authentification via SAML 2.0.

### Contexte Azure Marketplace

L'offre VM `nextcloud-marketplace` cible principalement des clients utilisant **Microsoft Azure**. Ces clients disposent nativement de **Microsoft Entra ID** comme fournisseur d'identité, qui supporte pleinement SAML 2.0.

### Contraintes

- **Techniques** : Nextcloud propose l'app native `user_saml` pour la fédération SAML 2.0
- **Azure Marketplace** : Réduire les dépendances externes instables pour garantir des builds reproductibles
- **Client final** : Simplifier l'intégration SSO avec l'écosystème Azure existant

---

## 💡 Décision

### Décision Principale

1. **Utiliser l'application `user_saml`** de Nextcloud comme couche SSO SAML 2.0 native
2. **Documenter Microsoft Entra ID comme IdP SAML 2.0 recommandé** pour les clients Azure
3. **Fournir une configuration SSO clé en main** dans la documentation post-déploiement
4. **Conserver la connexion admin locale** comme fallback (`/login?direct=1`)

### Architecture SSO

```
Navigateur client
      │
      ▼
Nextcloud (app user_saml)
      │ délègue l'authentification SAML 2.0
      ▼
Microsoft Entra ID (IdP — fournisseur d'identité)
      │ retourne les assertions SAML
      ▼
Nextcloud — session utilisateur créée
```

### Installation dans le provisioner `06-install-nextcloud.sh`

```bash
# ADR-302: Installation et activation app user_saml pour SSO SAML 2.0
OCC="php /var/www/nextcloud/occ"

# Installer l'application user_saml (disponible dans l'app store Nextcloud)
sudo -u www-data $OCC app:install user_saml || sudo -u www-data $OCC app:enable user_saml

# Créer une configuration SSO de base (complétée post-déploiement)
sudo -u www-data $OCC saml:config:create

# Mapping UID sur l'attribut email (UPN Entra ID)
sudo -u www-data $OCC config:app:set user_saml general-uid_mapping \
  --value="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
```

---

## 🔧 Configuration Microsoft Entra ID

### Prérequis

- Tenant Microsoft Entra ID (Azure AD)
- Droits d'administration pour créer une Enterprise Application

### URLs de Configuration SAML 2.0

| Paramètre | Valeur |
|-----------|--------|
| **Entity ID (SP)** | `https://{nextcloudHostname}/apps/user_saml/saml/metadata` |
| **ACS URL** | `https://{nextcloudHostname}/apps/user_saml/saml/acs` |
| **SLO URL** | `https://{nextcloudHostname}/apps/user_saml/saml/sls` |
| **Metadata URL (IdP)** | `https://login.microsoftonline.com/{tenant-id}/federationmetadata/2007-06/federationmetadata.xml` |

### Claims SAML Supportés

| Claim | Attribut Source | Usage Nextcloud |
|-------|----------------|-----------------|
| `NameID` | `user.userprincipalname` | Identifiant unique |
| `emailaddress` | `user.mail` | Email utilisateur |
| `givenname` | `user.givenname` | Prénom |
| `surname` | `user.surname` | Nom |
| `groups` | `user.assignedroles` | Groupes/Quotas |

### Configuration via occ (post-déploiement)

```bash
OCC="php /var/www/nextcloud/occ"
CONFIG_ID=1   # ID créé par saml:config:create

# IdP Entity ID
sudo -u www-data $OCC saml:config:set $CONFIG_ID \
  --idp-entityId="https://sts.windows.net/{tenant-id}/"

# IdP SSO URL
sudo -u www-data $OCC saml:config:set $CONFIG_ID \
  --idp-singleSignOnService.url="https://login.microsoftonline.com/{tenant-id}/saml2"

# Certificat IdP (copier depuis les métadonnées Entra ID)
sudo -u www-data $OCC saml:config:set $CONFIG_ID \
  --idp-x509cert="MIIC..."

# Mapping attributs
sudo -u www-data $OCC saml:config:set $CONFIG_ID \
  --general-uid_mapping="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" \
  --general-email_mapping="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress" \
  --general-displayName_mapping="http://schemas.microsoft.com/identity/claims/displayname"
```

---

## ⚖️ Alternatives Considérées

### Option 1 : Authentification locale uniquement (Rejeté)

- **Pour** : Aucune dépendance externe
- **Contre** : Pas d'intégration avec l'annuaire d'entreprise Entra ID
- **Décision** : ❌ Rejeté — Ne répond pas aux besoins SSO clients Azure

### Option 2 : user_oidc (OpenID Connect) (Non retenu pour la v1)

- **Pour** : Protocole plus moderne, configuration plus simple
- **Contre** : Moins universel que SAML 2.0 en entreprise ; nécessite app supplémentaire
- **Décision** : ⚠️ Non retenu pour la v1 — envisageable en alternative future

### Option 3 : user_saml (SAML 2.0) (Accepté) ✅

- **Pour** :
  - App native Nextcloud officielle (appstore.nextcloud.com)
  - Intégration native Azure via SAML 2.0
  - Haute disponibilité garantie par Microsoft
  - Simplification pour clients Azure Marketplace
  - Fallback authentification locale disponible (`/login?direct=1`)
- **Contre** : Configuration Entra ID requise post-déploiement
- **Décision** : ✅ Accepté

---

## 📋 Plan d'Implémentation

### Phase 1 : Build Image (Immédiat)

1. ✅ Installer et activer l'app `user_saml` dans `06-install-nextcloud.sh`
2. ✅ Créer une configuration SSO de base via `occ saml:config:create`
3. ✅ Rebuild image VM avec Packer

### Phase 2 : Documentation (Court terme)

1. Créer guide configuration Entra ID dans `/docs/guides/`
2. Documenter le remplacement des placeholders `{tenant-id}` et `{nextcloudHostname}`
3. Mettre à jour documentation offre Marketplace

### Phase 3 : Activation SSO Post-Déploiement

L'administrateur Nextcloud active le SSO en :
1. Créant l'Enterprise Application dans Entra ID avec les URLs SAML ci-dessus
2. Récupérant le certificat IdP depuis les métadonnées Entra ID
3. Configurant via `occ saml:config:set` ou l'interface admin Nextcloud

---

## 📚 Références

- [Application user_saml — Nextcloud App Store](https://apps.nextcloud.com/apps/user_saml)
- [Documentation user_saml — Nextcloud](https://docs.nextcloud.com/server/latest/admin_manual/enterprise/user_auth/user_saml.html)
- [Microsoft Entra ID - Configurer SSO basé sur SAML](https://learn.microsoft.com/fr-fr/entra/identity/enterprise-apps/add-application-portal-setup-sso)
- [Tutoriel : SSO Nextcloud avec Entra ID](https://learn.microsoft.com/fr-fr/entra/identity/saas-apps/nextcloud-tutorial)

---

## 🔄 Conséquences

### Positives

- ✅ Builds reproductibles sans dépendance externe instable
- ✅ Intégration SSO simplifiée pour clients Azure
- ✅ Certification Marketplace non bloquée
- ✅ Haute disponibilité IdP garantie par Microsoft
- ✅ Fallback authentification locale disponible (`/login?direct=1`)

### Négatives

- ⚠️ Configuration Entra ID requise par l'administrateur post-déploiement
- ⚠️ Documentation SSO à maintenir avec les valeurs tenant spécifiques au client

### Neutres

- Nextcloud reste accessible en authentification locale tant que le SSO n'est pas configuré
- Pas d'impact sur les autres méthodes d'authentification locales
