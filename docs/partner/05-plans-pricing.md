# Étape 5 — Plans & Pricing

> Partner Center : Offer → **Plans overview** → + Create new plan

---

## Plan : `standard`

### Plan identification

| Champ | Valeur |
|-------|--------|
| **Plan ID** | `standard` |
| **Plan name** | `Cotechnoe Cloud Hub — Standard` |

---

### Pricing model

| Champ | Valeur |
|-------|--------|
| **Pricing model** | Usage-based (Pay-as-you-go) |
| **License model** | Per vCPU |
| **Price** | `$0.07` USD / vCPU / heure |
| **Free trial** | 1 mois (recommandé pour adoption) |

> ⚠️ **Le modèle de prix NE PEUT PAS être modifié après la première publication.**

**Impact client :**

| VM Size | vCPU | Frais logiciel/h | Frais logiciel/mois |
|---------|------|------------------|---------------------|
| Standard_D2s_v3 (minimum) | 2 | $0.14/h | ~$102/mois |
| Standard_D4s_v3 (recommandée) | 4 | $0.28/h | ~$204/mois |
| Standard_D8s_v3 | 8 | $0.56/h | ~$409/mois |

---

### Markets

Tous les marchés disponibles (`Select all` dans Partner Center).

> Priority : Canada Central — inclus dans la liste par défaut.

---

### VM sizes recommandées

```
Minimum : Standard_D2s_v3  (2 vCPU, 8 GB RAM)
Recommandée : Standard_D4s_v3  (4 vCPU, 16 GB RAM)
```

---

### Disques

| Disque | Type | Taille | Rôle |
|--------|------|--------|------|
| OS disk | Premium SSD | 50 GB | Ubuntu 22.04 LTS + stack applicative |
| Data disk 0 | Premium SSD | 256 GB | MariaDB + données Nextcloud + logs |

> **Règle** : Tous les plans de l'offre doivent avoir le **même nombre de data disks**.
> Ici : 1 data disk — à maintenir pour tout plan futur.
