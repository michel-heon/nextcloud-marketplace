# Partner Center — Enregistrement Offre VM Nextcloud

> Référence principale : [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md)  
> Titre officiel retenu : [ADR-803](../adr/803-BIZ-titre-offre-marketplace-conformite-marque.md)

Ce répertoire documente les étapes d'enregistrement et de configuration de l'offre
**Cotechnoe Cloud Hub** dans Microsoft Partner Center.

---

## Identifiants de l'offre

| Champ | Valeur |
|-------|--------|
| **Publisher ID** | `cotechnoe` |
| **Offer ID** | `nextcloud-server` ← **IMMUABLE** après création |
| **Offer alias** | `Cotechnoe Cloud Hub VM` (interne Partner Center, invisible clients) |
| **Offer title** | `Cotechnoe Cloud Hub — Secure File Collaboration on Azure` |
| **Offer type** | Azure Virtual Machine |

---

## Pipeline de publication

```
Packer build (Ubuntu 22.04 LTS)
       ↓
Azure Compute Gallery — galNCMarketplace / nextcloud-server
  SecurityType = TrustedLaunch  ← OBLIGATOIRE (sinon invisible Partner Center)
       ↓
Partner Center > New Offer > Azure Virtual Machine
  ├── 1. Offer setup          → docs/partner/01-creation-offre.md
  ├── 2. Properties           → docs/partner/02-properties.md
  ├── 3. Offer listing        → docs/partner/03-offer-listing.md
  ├── 4. Preview audience     → docs/partner/04-preview.md
  ├── 5. Plans & pricing      → docs/partner/05-plans-pricing.md
  └── 6. Technical config     → docs/partner/06-technical-config.md
       ↓
Certification automatisée Microsoft (~ 3 jours ouvrables)
       ↓
Go Live → Azure Marketplace
```

---

## Prérequis avant d'ouvrir Partner Center

- [ ] Image `nextcloud-server` dans `galNCMarketplace` avec `SecurityType=TrustedLaunch`
- [ ] `make marketplace-gallery-permissions` exécuté (rôles Compute Gallery Image Reader)
- [ ] Logos préparés : 48×48, 90×90, 216×216 px PNG
- [ ] Screenshots préparés : 5 × 1280×720 px PNG (voir [screenshots-guide.md](../../nextcloud-azure-marketplace-doc/docs/marketplace/screenshots-guide.md))
- [ ] URL documentation : `https://github.com/Cotechnoe/nextcloud-azure-marketplace-doc/wiki`
- [ ] URL privacy policy : `https://github.com/Cotechnoe/nextcloud-azure-marketplace-doc/blob/main/PRIVACY.md`

---

## Index des étapes

| # | Étape | Fichier | Statut |
|---|-------|---------|--------|
| 1 | Création de l'offre (formulaire initial) | [01-creation-offre.md](01-creation-offre.md) | ✅ Complété |
| 2 | Properties (catégories, industries, légal) | [02-properties.md](02-properties.md) | 🔲 À faire |
| 3 | Offer listing (textes, logos, screenshots) | [03-offer-listing.md](03-offer-listing.md) | 🔲 À faire |
| 4 | Preview audience | [04-preview.md](04-preview.md) | 🔲 À faire |
| 5 | Plans & pricing | [05-plans-pricing.md](05-plans-pricing.md) | 🔲 À faire |
| 6 | Technical configuration (image gallery) | [06-technical-config.md](06-technical-config.md) | 🔲 À faire |
