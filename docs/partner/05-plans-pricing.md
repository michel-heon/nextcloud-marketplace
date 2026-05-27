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

### Tailles VM proposées (6) — recommandations internes

> ⚠️ Ces tailles VM sont des **recommandations internes Cotechnoe** pour Azure Marketplace.
> Elles sont alignées sur les bonnes pratiques Nextcloud (CPU/RAM, cache, tuning PHP-FPM, base de données, charge concurrente),
> mais **ne constituent pas** une grille officielle de tailles certifiées par Nextcloud.

Références officielles Nextcloud :
- [System requirements](https://docs.nextcloud.com/server/latest/admin_manual/installation/system_requirements.html)
- [Server tuning](https://docs.nextcloud.com/server/latest/admin_manual/installation/server_tuning.html)
- [Deployment recommendations](https://docs.nextcloud.com/server/latest/admin_manual/installation/deployment_recommendations.html)

Hypothèse de calcul (logiciel) : **0.023 USD / vCPU / heure** (730 h/mois).

| Taille VM | vCPU / RAM | Cas d'usage | Argument principal | Limite principale | Logiciel/mois (USD) |
|-----------|------------|-------------|--------------------|-------------------|---------------------|
| `Standard_B2s` | 2 / 4 GB | Démo, POC, sandbox interne | Coût d'entrée minimal pour valider déploiement et configuration initiale | RAM limitée pour usage collaboratif soutenu | ~$33.58 |
| `Standard_D2s_v3` | 2 / 8 GB | Petite équipe (jusqu'à ~20 utilisateurs légers) | Bon équilibre CPU/RAM pour fichiers, sync et apps de base | Peut saturer lors de pics (indexation, previews, scans) | ~$33.58 |
| `Standard_D4s_v3` | 4 / 16 GB | Standard SMB (20 à 75 utilisateurs) | Marge confortable pour PHP-FPM, Redis et jobs d'arrière-plan | Peut être surdimensionnée pour un petit POC | ~$67.16 |
| `Standard_E4s_v3` | 4 / 32 GB | Workloads orientés mémoire | Plus de RAM pour cache applicatif et métadonnées | Ratio RAM/CPU potentiellement sous-utilisé | ~$67.16 |
| `Standard_D8s_v3` | 8 / 32 GB | Équipes en croissance (75 à 200 utilisateurs) | Plus de parallélisme pour scans, transferts simultanés et tâches planifiées | Nécessite plus de tuning PHP/DB pour optimiser le coût | ~$134.32 |
| `Standard_E8s_v3` | 8 / 64 GB | Forte concurrence, gros volumes fichiers | Forte capacité mémoire pour réduire la pression I/O | Coût infra total plus élevé, à réserver aux besoins avérés | ~$134.32 |

Recommandation de sélection :
- Démarrer en `Standard_D4s_v3` pour la majorité des clients SMB.
- Descendre en `Standard_D2s_v3` pour petits tenants avec faible simultanéité.
- Monter vers `Standard_D8s_v3` ou `Standard_E8s_v3` si la latence augmente avec la concurrence utilisateur.

---

### Disques

| Disque | Type | Taille | Rôle |
|--------|------|--------|------|
| OS disk | Premium SSD | 30 GB | Ubuntu 24.04 LTS + stack applicative |
| Data disks | — | — | Aucun data disk attaché sur la VM de test |

> **Règle** : Tous les plans de l'offre doivent avoir le **même nombre de data disks**.
> Ici (image/VM de test actuelle) : 0 data disk — à maintenir pour tout plan futur.

---

### Plan listing (Partner Center)

Champs vus dans Partner Center :
- **Plan summary** (max 150 caractères)
- **Plan description** (max 3000 caractères)

Texte recommandé prêt à coller :

**Plan summary** (138/150)

```text
Pre-configured self-hosted Nextcloud VM on Azure with secure file sharing, SSO-ready setup, and data sovereignty in your own subscription.
```

**Plan description** (HTML léger, 1109/3000)

```html
<p><strong>Cotechnoe Cloud Hub — Standard</strong> is a pre-configured, self-hosted Nextcloud VM for organizations that need secure collaboration with full control of data residency on Azure. Deploy from Azure Marketplace and complete the first-boot wizard to configure domain and admin credentials.</p>

<p><strong>Included platform stack:</strong> Ubuntu 24.04 LTS, Nginx, PHP-FPM 8.3, PostgreSQL 16, Redis 7.</p>

<p><strong>Security baseline:</strong> SSH key authentication, UFW with ports 22/80/443 only, PostgreSQL bound to localhost, automatic HTTP-to-HTTPS redirect, HSTS, fail2ban, and unattended security updates.</p>

<p>This plan is suitable for production pilots and small-to-medium teams. Recommended sizing starts at Standard_D2s_v3 (2 vCPU, 8 GB RAM) and scales to Standard_D4s_v3 and above based on users and workload.</p>

<p><strong>Data sovereignty by design:</strong> data stays in your Azure subscription and selected region.</p>

<p><em>Nextcloud is a registered trademark of Nextcloud GmbH. This offer is published by Cotechnoe and is not affiliated with or endorsed by Nextcloud GmbH.</em></p>
```
