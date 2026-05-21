---
adr: 617
title: "HashiCorp Packer — Outil de Construction d'Images VM Azure"
status: "accepted"
date: 2026-05-09
superseded_by: null
replaces: null
related_adrs: [200, 600, 613, 614, 616]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "high"
  quality:
    - "reliability"
    - "maintainability"
    - "portability"
    - "compliance"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "packer"
    - "azure"
    - "bash"

tags: ["packer", "vm-image", "azure-arm", "hcl2", "golden-image", "azure-marketplace", "compute-gallery"]
stakeholders: ["@devops-team", "@architecture-team"]
effort: "medium"
---

# ADR-617 : HashiCorp Packer — Outil de Construction d'Images VM Azure

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-05-09 |
| **Stakeholders** | @devops-team, @architecture-team |
| **Impact** | 🔴 Élevé |
| **Effort Implémentation** | 🟡 Moyen |
| **Risque Technique** | 🟢 Faible |

---

## 🎯 Contexte & Problème

La publication d'une offre VM sur Azure Marketplace exige une image de machine virtuelle
reproductible, immutable, et conforme aux exigences de certification Microsoft. Cette image
doit inclure l'OS (Ubuntu 22.04 LTS), la pile applicative (PHP 8.2, Nginx, MariaDB, Redis,
Nextcloud Hub), ainsi que tous les hardening de sécurité documentés dans ADR-300.

Sans outillage dédié, la construction d'une telle image est manuelle, non reproductible, et
difficilement auditée — trois critères éliminatoires pour une publication Marketplace.

**Besoin central** : disposer d'un outil capable de construire, de façon automatisée et
déclarative, une image VM Azure identique à chaque exécution, à partir d'une configuration
versionnée dans Git.

---

## 💡 Décision

**Utiliser HashiCorp Packer** (v1.11+) avec le plugin officiel `hashicorp/azure` (v2.x) et le
builder `azure-arm` pour construire toutes les images VM du projet `nextcloud-marketplace`.

Les templates sont écrits en **HCL2** (fichiers `.pkr.hcl`), versionné dans Git, et exécutés
dans le pipeline DevOps.

### Référence officielle

- Documentation : <https://developer.hashicorp.com/packer>
- Plugin Azure : <https://developer.hashicorp.com/packer/integrations/hashicorp/azure>
- Licence : Business Source License 1.1 (BSL 1.1) depuis août 2023 — usage interne et
  commercial autorisé ; redistribution du produit Packer lui-même soumise à restriction.

---

## 🏗️ Architecture de la Solution

### Structure du template principal

```hcl
# packer/nextcloud-vm.pkr.hcl

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

variable "nc_version"       { type = string }
variable "nextcloud_version" { type = string }
variable "php_version"       { type = string }
variable "build_date"        { type = string }

locals {
  image_version = "${var.nc_version}.${var.build_date}"  # ex: 6.0.1.20260501
}

source "azure-arm" "nextcloud" {
  # Authentification — Service Principal via variables d'environnement
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID

  resource_group_name = "rg-nextcloud-marketplace"
  storage_account     = "stncmarketplace"

  # Image de base (Azure endorsée)
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  os_type         = "Linux"

  # Taille VM de build (plus grande que la cible finale pour accélérer la construction)
  vm_size = "Standard_D4s_v3"

  # Destination : Azure Compute Gallery
  shared_image_gallery_destination {
    resource_group  = "rg-nextcloud-marketplace"
    gallery_name    = "galNCMarketplace"
    image_name      = "nextcloud"
    image_version   = local.image_version
    replication_regions = ["canadacentral"]
  }
}

build {
  sources = ["source.azure-arm.nextcloud"]

  # Séquence des provisioners shell (voir ADR-613)
  provisioner "shell" {
    script = "provisioners/01-install-base.sh"
  }
  provisioner "shell" {
    script = "provisioners/02-install-php.sh"
    environment_vars = [
      "PHP_VERSION=${var.php_version}",
    ]
  }
  # ... autres provisioners jusqu'à 08-cleanup-generalize.sh

  # Generalisation de l'image (obligatoire pour Azure Marketplace)
  provisioner "shell" {
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
  }
}
```

### Flux d'exécution Packer

```
packer init packer/          # Télécharge le plugin azure ~> 2
packer validate packer/      # Valide la syntaxe HCL2 et les variables
packer build packer/         # Lance le build dans Azure
```

1. Packer provisionne une VM temporaire dans `rg-nextcloud-marketplace-build`
2. Les scripts `provisioners/0X-*.sh` s'exécutent séquentiellement via SSH
3. La VM est généralisée (`waagent -deprovision+user`)
4. L'image est publiée dans `galNCMarketplace/nextcloud/{version}`
5. La VM temporaire et ses ressources associées sont supprimées automatiquement

---

## ⚖️ Alternatives Évaluées

### 1. Azure Image Builder (AIB)

| Critère | AIB | Packer |
|---------|-----|--------|
| Configuration | JSON/YAML propriétaire Azure | HCL2 standard, versionnable |
| Portabilité | Azure uniquement | Multi-cloud (Azure, AWS, GCP, VMware…) |
| Debug/logs | Via Azure Monitor | PACKER_LOG local ou CI |
| Communauté | Microsoft uniquement | HashiCorp + large communauté open source |
| Intégration Git/CI | Limitée | Natif (CLI + variables d'environnement) |

**Rejeté** : la dépendance Azure-only et la configuration propriétaire réduisent la
portabilité et la maintenabilité du pipeline.

### 2. Construction manuelle (capture de VM Azure)

Créer une VM, la configurer manuellement, puis la capturer via le portail Azure ou la CLI.

**Rejeté** : non reproductible, non auditable, impossible à versionner dans Git, interdit de
facto par les pratiques DevOps documentées dans ADR-602 (Makefile) et ADR-603 (Git workflow).

### 3. Dockerfile / conteneur → conversion image VM

Partir d'une image Docker et convertir en image VM.

**Rejeté** : Azure Marketplace VM Offer requiert une image Linux native généralisant
correctement (waagent), ce que le flux Docker→VM ne garantit pas sans friction significative.

---

## 📋 Authentification

Packer supporte deux modes d'authentification Azure (source : documentation officielle) :

### Service Principal (pipeline CI/CD)

Variables d'environnement standard ARM :

```bash
export ARM_CLIENT_ID="<app-id>"
export ARM_CLIENT_SECRET="<secret>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
```

### Managed Identity (VM de build Azure)

Si Packer s'exécute sur une VM Azure dotée d'une Managed Identity, aucune variable
d'authentification n'est nécessaire. Packer détecte automatiquement l'identité et l'abonnement.

---

## 🔧 Commandes Makefile Associées

Conformément à ADR-602, les commandes Packer sont exposées via des cibles Makefile :

```makefile
packer-init:       ## Initialise le plugin azure (~> 2)
	packer init packer/

packer-validate:   ## Valide le template HCL2
	packer validate -var-file=packer/variables.pkrvars.hcl packer/

nextcloud-build:         ## Construit l'image VM et la publie dans la Compute Gallery
	packer build -var-file=packer/variables.pkrvars.hcl packer/
```

---

## ✅ Conséquences

### Positives

- **Reproductibilité** : chaque exécution produit une image identique à partir du même commit Git
- **Traçabilité** : le numéro de version (`{NC_VERSION}.{YYYYMMDD}`) est inscrit dans la
  Compute Gallery et lié au commit Git (voir ADR-603)
- **Infrastructure as Code** : le template `.pkr.hcl` est versionné, reviewable, et testable
- **Nettoyage automatique** : Packer détruit la VM temporaire de build après chaque exécution,
  quelle qu'en soit l'issue (succès ou échec)
- **Debug possible** : `PACKER_LOG=1` active les logs détaillés pour le troubleshooting local

### Contraintes à gérer

- **Licence BSL 1.1** : Packer ne peut pas être redistribué comme produit commercial dérivé ;
  l'usage pour construire des images destinées à Azure Marketplace est autorisé
- **Temps de build** : 10 à 20 minutes par image complète (installation PHP, Nginx, MariaDB,
 ; le cache Blob Storage (ADR-616) réduit ce délai
- **Coût Azure** : une VM `Standard_D4s_v3` est provisionnée pendant la durée du build ;
  elle est facturée au prorata (typiquement < 0,20 € par build)

---

## 🔗 Références

| Ressource | URL |
|-----------|-----|
| Documentation officielle Packer | <https://developer.hashicorp.com/packer/docs/intro> |
| Templates HCL2 | <https://developer.hashicorp.com/packer/docs/templates/hcl_templates> |
| Plugin Azure (azure-arm) | <https://developer.hashicorp.com/packer/integrations/hashicorp/azure> |
| Builder azure-arm | <https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm> |
| ADR-200 | Infrastructure Azure (Compute Gallery, NSG) |
| ADR-613 | Architecture des provisioners Packer |
| ADR-616 | Cache Blob Storage pour les builds Packer |
