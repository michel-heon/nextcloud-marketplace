---
# 🤖 Machine-Readable Metadata (Frontmatter YAML)
adr: 302
title: "Authentification SSO via Microsoft Entra ID avec PluggableAuth + SimpleSAMLphp"
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
    - "mediawiki"
    - "saml"

tags: ["azure-marketplace", "sso", "entra-id", "saml", "authentication", "mediawiki", "pluggableauth", "simplesamlphp"]
stakeholders: ["@architecture-team", "@dev-team"]
effort: "medium"
---

# ADR 302: Authentification SSO via Microsoft Entra ID avec PluggableAuth + SimpleSAMLphp

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

MediaWiki ne dispose pas d'un mécanisme SSO natif intégré. Pour les clients de l'offre Azure Marketplace qui utilisent **Microsoft Entra ID** (anciennement Azure AD) comme fournisseur d'identité, il est nécessaire d'intégrer un mécanisme d'authentification fédérée SAML 2.0.

### Contexte Azure Marketplace

L'offre VM `smw-marketplace` cible principalement des clients utilisant **Microsoft Azure**. Ces clients disposent nativement de **Microsoft Entra ID** comme fournisseur d'identité, qui supporte pleinement SAML 2.0.

### Contraintes

- **Techniques**: MediaWiki nécessite une extension pour déléguer l'authentification à un IdP SAML 2.0
- **Azure Marketplace**: Réduire les dépendances externes instables pour garantir des builds reproductibles
- **Client final**: Simplifier l'intégration SSO avec l'écosystème Azure existant

---

## 💡 Décision

### Décision Principale

1. **Utiliser l'extension PluggableAuth** comme couche d'abstraction d'authentification dans MediaWiki
2. **Utiliser SimpleSAMLphp** comme SP SAML 2.0 pour la communication avec Entra ID
3. **Documenter Microsoft Entra ID comme IdP SAML 2.0 recommandé** pour les clients Azure
4. **Fournir une configuration SSO clé en main** dans la documentation

### Architecture SSO

```
Navigateur client
      │
      ▼
MediaWiki (PluggableAuth extension)
      │ délègue l'authentification
      ▼
SimpleSAMLphp (SP SAML 2.0 — /opt/simplesamlphp/)
      │ échange SAML 2.0
      ▼
Microsoft Entra ID (IdP — fournisseur d'identité)
```

### Installation dans le provisioner `06-install-smw.sh`

```bash
# ADR-302: Installation SimpleSAMLphp pour SSO SAML 2.0
cd /opt
composer create-project simplesamlphp/simplesamlphp simplesamlphp --no-interaction

# Installation extensions MediaWiki SSO
cd /opt/mediawiki
php maintenance/run.php install --with-extensions

# Activer PluggableAuth dans LocalSettings.php
cat >> /opt/mediawiki/LocalSettings.php <<'EOF'
# ADR-302: SSO via Microsoft Entra ID
wfLoadExtension('PluggableAuth');
$wgPluggableAuth_Config['Microsoft Entra ID'] = [
    'plugin'  => 'SimpleSAMLphp',
    'data'    => ['authsource' => 'entra-id'],
];
$wgPluggableAuth_EnableAutoLogin = false;
$wgPluggableAuth_EnableLocalLogin = true;
EOF
```

---

## 🔧 Configuration Microsoft Entra ID

### Prérequis

- Tenant Microsoft Entra ID (Azure AD)
- Droits d'administration pour créer une Enterprise Application

### URLs de Configuration SAML 2.0

| Paramètre | Valeur |
|-----------|--------|
| **Login URL** | `https://login.microsoftonline.com/{tenant-id}/saml2` |
| **Logout URL** | `https://login.microsoftonline.com/{tenant-id}/saml2` |
| **Azure AD Identifier (Entity ID)** | `https://sts.windows.net/{tenant-id}/` |
| **Metadata URL** | `https://login.windows.net/{tenant-id}/federationmetadata/2007-06/federationmetadata.xml?appid={application-id}` |

### Claims SAML Supportés

| Claim | Attribut Source | Usage MediaWiki |
|-------|----------------|-----------------|
| `NameID` | `user.userprincipalname` | Identifiant unique |
| `emailaddress` | `user.mail` | Email utilisateur |
| `givenname` | `user.givenname` | Prénom |
| `surname` | `user.surname` | Nom |
| `groups` | `user.assignedroles` | Groupes/Rôles |

### Configuration SimpleSAMLphp (`authsources.php`)

```php
// ADR-302: Source d'authentification Microsoft Entra ID
'entra-id' => [
    'saml:SP',
    'entityID' => 'https://your-wiki-domain.com/simplesaml/module.php/saml/sp/metadata/entra-id',
    'idp'      => 'https://sts.windows.net/{tenant-id}/',
    'discoURL' => null,
],
```

---

## ⚖️ Alternatives Considérées

### Option 1: Authentification locale uniquement (Rejeté)

- **Pour**: Aucune dépendance externe
- **Contre**: Pas d'intégration avec l'annuaire d'entreprise Entra ID
- **Décision**: ❌ Rejeté — Ne répond pas aux besoins SSO clients Azure

### Option 2: Extension LDAPAuthentication2 (Rejeté)

- **Pour**: Simple pour LDAP/Active Directory
- **Contre**: LDAP non natif sur Entra ID; nécessite LDAPS ou AD Connect
- **Décision**: ❌ Rejeté — SAML 2.0 est l'approche recommandée par Microsoft pour Entra ID

### Option 3: PluggableAuth + SimpleSAMLphp (Accepté) ✅

- **Pour**:
  - Intégration native Azure via SAML 2.0
  - Haute disponibilité garantie par Microsoft
  - Simplification pour clients Azure Marketplace
  - Extensions officiellement supportées par MediaWiki (mediawiki.org)
  - `wgPluggableAuth_EnableLocalLogin = true` permet le fallback en local
- **Contre**: Configuration initiale requise post-déploiement
- **Décision**: ✅ Accepté

---

## 📋 Plan d'Implémentation

### Phase 1: Build Image (Immédiat)

1. ✅ Installer SimpleSAMLphp via Composer dans `06-install-smw.sh`
2. ✅ Installer et activer l'extension PluggableAuth
3. ✅ Pré-configurer LocalSettings.php avec les stubs SSO commentés
4. ✅ Rebuild image VM avec Packer

### Phase 2: Documentation (Court terme)

1. Créer guide configuration Entra ID dans `/docs/guides/`
2. Mettre à jour documentation offre Marketplace
3. Documenter le remplacement des placeholders `{tenant-id}` et `{application-id}`

### Phase 3: Activation SSO Post-Déploiement

L'administrateur du wiki active le SSO en:
1. Créant l'Enterprise Application dans Entra ID
2. Mettant à jour `{tenant-id}` et `{application-id}` dans `authsources.php`
3. Activant `wgPluggableAuth_EnableAutoLogin` si souhaité

---

## 📚 Références

- [Extension PluggableAuth — MediaWiki](https://www.mediawiki.org/wiki/Extension:PluggableAuth)
- [Extension SimpleSAMLphp — MediaWiki](https://www.mediawiki.org/wiki/Extension:SimpleSAMLphp)
- [SimpleSAMLphp — Documentation officielle](https://simplesamlphp.org/docs/stable/)
- [Microsoft Entra ID - Configurer SSO basé sur SAML](https://learn.microsoft.com/fr-fr/entra/identity/enterprise-apps/add-application-portal-setup-sso)
- [Migration ADFS vers Entra ID](https://learn.microsoft.com/fr-fr/entra/identity/enterprise-apps/migrate-adfs-saml-based-sso)

---

## 🔄 Conséquences

### Positives

- ✅ Builds reproductibles sans dépendance externe instable
- ✅ Intégration SSO simplifiée pour clients Azure
- ✅ Certification Marketplace non bloquée
- ✅ Haute disponibilité IdP garantie par Microsoft
- ✅ Fallback authentification locale disponible (`wgPluggableAuth_EnableLocalLogin`)

### Négatives

- ⚠️ Configuration Entra ID requise par l'administrateur post-déploiement
- ⚠️ Documentation SSO à maintenir avec les valeurs tenant spécifiques au client

### Neutres

- MediaWiki reste accessible en authentification locale tant que le SSO n'est pas configuré
- Pas d'impact sur les autres méthodes d'authentification locales
