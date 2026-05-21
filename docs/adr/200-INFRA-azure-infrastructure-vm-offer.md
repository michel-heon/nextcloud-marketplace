---
adr: 200
title: "Infrastructure Azure — VM Offer : Compute Gallery, NSG, ARM Template, Data Disk"
status: "accepted"
date: 2026-02-22
superseded_by: null
replaces: null
related_adrs: [300, 600, 800]
related_issues: [5, 30, 31]

classification:
  lifecycle: "accepted"
  domain: "infrastructure"
  impact: "high"
  quality:
    - "reliability"
    - "security"
    - "portability"
    - "compliance"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "azure"
    - "packer"
    - "arm"
    - "marketplace"
    - "nsg"

tags: ["azure", "compute-gallery", "nsg", "arm-template", "data-disk", "vm-offer", "partner-center"]
stakeholders: ["@devops-team", "@architecture-team"]
effort: "high"
---

# ADR-200 : Infrastructure Azure — VM Offer

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-04-01 |
| **Impact** | 🔴 Élevé |
| **Risque technique** | 🟡 Moyen |
| **Portée** | Stratégique — définit tous les artefacts Azure du pipeline de publication |

---

## 🎯 Contexte

La publication d'une VM Offer sur Azure Marketplace requiert une infrastructure Azure précise :
une Compute Gallery pour versionner les images, des règles NSG conformes aux exigences de certification, un ARM template que le client exécute lors du déploiement, et un data disk séparé pour les données persistantes MediaWiki (MySQL, uploads, logs).

---

## 💡 Décisions

### 1. OS de Base : Ubuntu 22.04 LTS

**Ubuntu 22.04 LTS Jammy** — image Azure endorsée, support jusqu'à avril 2027.

```hcl
# packer/smw-vm.pkr.hcl
source "azure-arm" "smw" {
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  os_type         = "Linux"
  vm_size         = "Standard_D4s_v3"    # build Packer (PHP + MediaWiki ~10-15 min)
}
```

### 2. Azure Compute Gallery

Structure de versionnement des images :

```
galSMWMarketplace/                   ← Azure Compute Gallery
  └── smw-knowledge-base/   ← Image Definition
        ├── 7.6.0.YYYYMMDD                ← Image Version (immutable)
        └── ...
```

****Tag de version** : `{SMW_VERSION}.{YYYYMMDD}` (ex: `6.0.1.20260401`).

**Région** : `canadaeast` (primaire) + `eastus` (réplication — requis Marketplace).

### 3. NSG — Network Security Group

| Règle | Port | Protocole | Source | Justification |
|-------|------|-----------|--------|--------------|
| HTTPS-IN | 443 | TCP | * | Accès MediaWiki clients |
| HTTP-IN | 80 | TCP | * | Redirect → HTTPS uniquement |
| SSH-IN | 22 | TCP | IP admin uniquement | Administration (restreint ADR-300) |
| MYSQL-DENY | 3306 | TCP | * | MySQL jamais exposé publiquement |
| APACHE-INT | 8080 | TCP | * | Apache/PHP-FPM interne uniquement |
| PHP-FPM-DENY | 9000 | TCP | * | PHP-FPM jamais exposé publiquement |
| MEDIAWIKI-INT | 80 | TCP | * | MediaWiki via nginx uniquement |

**Règle critique** : MySQL et PHP-FPM ne doivent **jamais** être exposés. Ils écoutent sur `127.0.0.1` uniquement (liaison locale dans les services systemd).

### 4. Data Disk — Stockage Persistant

**Exigence Microsoft** : les données clients ne doivent pas résider sur le disque OS (perte lors des opérations de généralisation/resize).

| Paramètre | Valeur |
|-----------|--------|
| Type | Premium SSD LRS |
| Taille recommandée | 128 GB (paramètre ARM configurable par client) |
| Point de montage | `/data` |
| Filesystem | ext4 |
| Formatage | `cloud-init` au premier boot si disque vierge |

```yaml
# cloud-init snippet : montage data disk
runcmd:
  - |
    DISK=/dev/sdc
    if ! blkid "$DISK" > /dev/null 2>&1; then
      mkfs.ext4 "$DISK"
    fi
    mkdir -p /data
    echo "$DISK /data ext4 defaults,nofail 0 2" >> /etc/fstab
    mount -a
    mkdir -p /data/mysql /data/uploads /data/logs
```

### 5. Tailles VM Recommandées (ARM template)

| Scénario | SKU | vCPU | RAM | Coût/mois estimé |
|----------|-----|------|-----|-----------------|
| Développement / demo | Standard_D2s_v3 | 2 | 8 GB | ~$70 USD |
| Production petite bibliothèque | Standard_D4s_v3 | 4 | 16 GB | ~$140 USD |
| Production grande université | Standard_D8s_v3 | 8 | 32 GB | ~$280 USD |

****Minimum requis** : `Standard_D2s_v3` (MySQL + Apache + PHP-FPM + MediaWiki nécessite 8 GB+ RAM disponible).

### 6. ARM Template — createUIDefinition.json

Paramètres exposés au client dans le formulaire Marketplace :

```json
{
  "parameters": {
    "adminUsername":      { "type": "string" },
    "adminPublicKey":     { "type": "securestring" },
    "vmSize":             { "type": "string", "defaultValue": "Standard_D4s_v3" },
    "dataDiskSizeGB":     { "type": "int",    "defaultValue": 128 },
    "wikiUrl":          { "type": "string" },
    "wikiAdminEmail":   { "type": "string" },
    "mysqlPassword": { "type": "securestring" },
    "postgresPassword":   { "type": "securestring" },
    "sshSourceIP":        { "type": "string", "defaultValue": "*" }
  }
}
```

---

## 📦 Pipeline Infrastructure Complet

```
make packer-build
    │
    ▼ (~30 min : Maven build + provisioners + généralisation)
Azure Compute Gallery
  galSMWMarketplace/server-knowledge-graph/1.16.0.YYYYMMDD
    │
    ▼
Partner Center > Technical Configuration
  (référence image Gallery)
    │
    ▼
Client déploie depuis Azure Marketplace
  → ARM template exécuté
  → VM créée depuis image Gallery
  → cloud-init : montage data disk + injection params
  → MediaWiki accessible sur https://{vm-ip}/
```

---

## 📎 Références

- ADR-100 : Architecture Docker-first (source de vérité Dockerfiles)
- ADR-300 : Sécurité hardening OS
- ADR-600 : Bootstrap / variables d'environnement (`IMAGE_GALLERY`, `AZURE_RESOURCE_GROUP`)
- ADR-700 : Stratégie waagent + généralisation
- ADR-800 : Publication Azure Marketplace (Partner Center, permissions Gallery)
- Issue #30 : ARM template createUIDefinition.json + mainTemplate.json
- Issue #31 : Packer build Azure → Compute Gallery
