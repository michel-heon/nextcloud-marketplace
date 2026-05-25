# Étape 1 — Création de l'offre (formulaire initial)

> **URL Partner Center** : https://partner.microsoft.com/dashboard/marketplace-offers/overview  
> Navigation : Marketplace offers > + New offer > Azure Virtual Machine

---

## Contexte

La capture d'écran ci-dessous correspond au panneau **"Create a new offer"** affiché
après avoir cliqué sur **+ New offer → Azure Virtual Machine** dans le Partner Center.

Ce formulaire contient deux champs seulement, mais ils sont **critiques** :
- **Offer ID** : identifiant technique permanent — **IMPOSSIBLE à modifier après création**
- **Offer alias** : nom interne Partner Center, invisible sur la place de marché

---

## Formulaire : Create a new offer

### Offer ID

```
nextcloud-server
```

**Règles** :
- Uniquement minuscules, alphanumériques, tirets (`-`) ou underscores (`_`)
- Ne peut pas terminer par `-preview`
- **Ne peut pas être modifié après avoir cliqué Create**
- Maximum 50 caractères

**Justification** : Valeur décidée dans ADR-800 (§ Décision 1). Cohérent avec
l'image definition `nextcloud-server` dans `galNCMarketplace` et le publisher
`cotechnoe`. L'URL Marketplace sera :
`https://azuremarketplace.microsoft.com/marketplace/apps/cotechnoe.nextcloud-server`

> ⚠️ **ATTENTION** : Si l'offre existe déjà avec l'ID `nextcloud-server`, ne pas
> en créer une nouvelle. Cliquer sur l'offre existante dans la liste.

---

### Offer alias

```
Cotechnoe Cloud Hub VM
```

**Règles** :
- Nom purement interne à Partner Center
- N'apparaît PAS sur Azure Marketplace
- Peut être modifié ultérieurement
- Sert de label de référence dans les listes Partner Center

**Justification** : Identifie clairement l'offre dans les listes Partner Center
sans violer les politiques de marque Microsoft (ADR-803). Le nom affiché
publiquement sur le Marketplace est configuré à l'étape **Offer listing** (étape 3).

---

## Action

1. Naviguer vers : [partner.microsoft.com](https://partner.microsoft.com/dashboard/marketplace-offers/overview)
2. Cliquer **+ New offer** → **Azure Virtual Machine**
3. Remplir les champs :
   - **Offer ID** : `nextcloud-server`
   - **Offer alias** : `Cotechnoe Cloud Hub VM`
4. Cliquer **Create**

---

## Résultat attendu

Après **Create**, Partner Center redirige vers le tableau de bord de l'offre avec
les sections suivantes dans le menu gauche :

- Overview
- Offer setup
- **Properties** → étape suivante ([02-properties.md](02-properties.md))
- Offer listing
- Preview audience
- Plans overview
- Reseller
- Review and publish

---

## Historique des soumissions

| Date | Offer ID soumis | Offer alias | Résultat |
|------|----------------|-------------|----------|
| 2026-05-25 | `nextcloud-server` | `Cotechnoe Cloud Hub VM` | Formulaire initial créé |
