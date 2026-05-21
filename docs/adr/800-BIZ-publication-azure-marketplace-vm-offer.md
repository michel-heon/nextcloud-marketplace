---
adr: 800
title: "Publication Offre VM sur Azure Marketplace — Conformité et Bonnes Pratiques Microsoft"
status: "accepted"
date: 2026-04-16
classification:
  lifecycle: "accepted"
  domain: "biz"
  impact: "high"
  quality:
    - "compliance"
    - "reliability"
    - "security"
    - "portability"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "azure"
    - "marketplace"
    - "packer"
    - "tls"
    - "security"
    - "mediawiki"
    - "smw"

tags: ["azure-marketplace", "vm-offer", "certification", "partner-center", "packer", "open-source", "byol", "compliance", "smw", "mediawiki"]
stakeholders: ["@dev-team", "@devops-team", "@architecture-team"]
effort: "high"
related_issues: []
related_adrs: [600, 602, 613, 200]
replaces: null
superseded_by: null
---

# ADR 800: Publication Offre VM sur Azure Marketplace — Conformité et Bonnes Pratiques Microsoft

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-04-16 |
| **Impact** | 🔴 Élevé (détermine la viabilité de la publication) |
| **Domaine** | BIZ / Marketplace |
| **Réversibilité** | 🟡 Modérée |
| **Portée** | Processus complet de publication : image → Partner Center → Marketplace live |

**Sources Microsoft** :
- [Plan a VM offer](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-virtual-machines)
- [Create VM from approved base](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-use-approved-base)
- [VM Certification FAQ](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-certification-faq)
- [Marketplace listing guidelines](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/marketplace-criteria-content-validation)
- **[Commercial Marketplace Certification Policies v1.67](https://learn.microsoft.com/en-us/legal/marketplace/certification-policies)** — Référence officielle sections 100 (Général), 200 (VMs), 200.5 (Sécurité)

## 🎯 Contexte

Le projet **smw-marketplace** vise à publier une offre de type **Virtual Machine (VM)** sur Microsoft Azure Marketplace intégrant **Semantic MediaWiki** (MediaWiki 1.43.x + SMW 6.0.1 + PHP 8.2 + MySQL 8.x + Apache 2.4), destinée aux organisations gérant une base de connaissances sémantique.

Microsoft impose un ensemble d'exigences techniques, de sécurité et de contenu pour qu'une image VM soit certifiée et publiée. Sans conformité à ces exigences, le processus de certification échoue automatiquement.

Ce document centralise ces exigences, les décisions prises pour y répondre, et leur traçabilité vers les ADRs techniques correspondants.

### Mapping Certification Policies → Décisions ADR

| Section Microsoft | Titre | Décision ADR correspondante |
|-------------------|-------|----------------------------|
| **100.1.1** | Title requirements | Décision 5 (Titre) |
| **100.1.2** | Summary requirements (100 chars max) | Décision 5 (Summary) |
| **100.1.3** | Description requirements | Décision 5 (Description) |
| **100.2.2** | Keywords (max 20) | Décision 5 (Keywords) |
| **100.3** | Graphics requirements | Décision 5 (Logos, Screenshots) |
| **100.4** | Pricing requirements | Décision 4 (Modèle de licence) |
| **200.1** | Technical requirements | Décision 1 (Prérequis) |
| **200.2** | Business requirements | Décision 1 (Partner Center) |
| **200.3** | VM Image requirements | Décision 2 (Image VM) |
| **200.3.3** | Linux-specific requirements | Décision 2 + 3 (SSH, hv_netvsc, swap) |
| **200.4** | Generalization requirements | Décision 2 (waagent) |
| **200.5** | Security requirements | Décision 3 (TLS, patches, CVE, hardening) |
| **200.6** | Testing and certification | Décision 8 (Tests, SAS URI) |

## 💡 Décision

**Nous adoptons les bonnes pratiques Microsoft pour la publication d'une offre VM et nous engageons à respecter l'ensemble des exigences du processus de certification Azure Marketplace.**

---

## 📦 Chaîne de Publication

```
Packer build (Ubuntu 22.04 LTS)
       ↓
Azure Compute Gallery (image versionnée, généralisée)
       ↓
Partner Center > New Offer > Azure Virtual Machine
  ├── Offer setup (ID, alias, publisher)
  ├── Properties (catégories, industries, version légale)
  ├── Offer listing (titre, description, logo, screenshots)
  ├── Plans & Pricing (modèle de licence)
  ├── Technical configuration (référence image Compute Gallery)
  └── Preview audience (test interne avant publication)
       ↓
Certification automatisée Microsoft
       ↓
Microsoft Marketplace Live
```

---

## ⚙️ Décision 1 : Prérequis Administratifs

### Compte Partner Center

- **Compte Partner Center** requis et inscrit au programme **Microsoft Marketplace commercial**
- Variables à provisionner (voir ADR-600 bootstrap) :

```bash
# env/.env.dev
MARKETPLACE_PUBLISHER_ID="cotechnoe"
OFFER_ID="smw-knowledge-base"          # max 50 chars, minuscules, tirets, IMMUABLE après création
OFFER_ALIAS="SMW Knowledge Base VM"    # Nom interne Partner Center (invisible clients)
IMAGE_GALLERY="galSMWMarketplace"      # Azure Compute Gallery pour les images
```

### Contrainte tenant Entra

L'**Azure Compute Gallery** (où Packer publie les images) et le compte **Partner Center** doivent être dans le **même tenant Microsoft Entra**. Risque si le projet utilise plusieurs tenants Azure.

### Permissions Azure Compute Gallery pour Partner Center

> ⚠️ **Obligation pré-publication — à exécuter une fois par gallery, et après toute
> recréation de gallery.**
> Sans ces permissions, Partner Center refuse d'indexer la version d'image et
> affiche l'erreur `"The image reference is not accessible"` dans la configuration
> technique.
>
> Référence Microsoft : <https://aka.ms/ComputeGalleryPermissions>

#### Contexte

Partner Center utilise deux Service Principals (SPs) pour accéder à la gallery lors
de la publication. Ces SPs doivent recevoir le rôle
**`Compute Gallery Image Reader`** (`cf7c76d2-98a3-4358-a134-615aa78bf44d`) directement
sur la gallery (scope gallery, pas subscription).

| Service Principal | Rôle dans Partner Center | ID objet (tenant `aba0984a`) |
|---|---|---|
| `Microsoft Partner Center Resource Provider` | Ingestion des images lors de la publication | `497d76fa-f477-478a-aa29-49b0dee35030` |
| `Compute Image Registry` | Validation et réplication des images | `5947d96b-019a-46ba-ad4b-8ffc6f493b2e` |

> Note : Ces IDs d'objet sont stables dans un tenant donné mais peuvent différer
> entre tenants. Le script les résout dynamiquement par leur nom d'affichage.

#### Exécution

```bash
# Target Makefile (ADR-602) — idempotente, safe à relancer
make marketplace-gallery-permissions
```

Le target délègue à `packer/scripts/marketplace-gallery-permissions.sh` qui :
1. Enregistre le RP `Microsoft.PartnerCenterIngestion` (si absent)
2. Résout l'ID de la gallery `galSMWMarketplace` dans `rg-smw-marketplace`
3. Crée les deux assignations de rôle (skip si déjà existantes)
4. Vérifie le résultat final

#### Vérification manuelle

```bash
# Lister les assignations sur la gallery
GALLERY_ID=$(az sig show \
  --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace \
  --query id -o tsv)
az role assignment list --scope "$GALLERY_ID" \
  --query "[?contains(roleDefinitionId,'cf7c76d2')].{SP:principalId,Rôle:roleDefinitionName}" \
  -o table
# Attendu : 2 lignes "Compute Gallery Image Reader"
```

#### Quand re-exécuter

| Événement | Action requise |
|---|---|
| Première configuration Partner Center | ✅ Obligatoire |
| Recréation de la gallery (`az sig delete` + recréation) | ✅ Obligatoire |
| Nouvel abonnement / nouveau tenant | ✅ Obligatoire |
| Nouveau build d'image (même gallery) | ❌ Non requis |
| Nouvelle version d'image dans la même gallery | ❌ Non requis |

---

## 🖼️ Décision 2 : Exigences Image VM (Linux)

### OS de base

**Décision** : Ubuntu 22.04 LTS Jammy (endorsed par Azure, support jusqu'à 2027).

```
approved: ubuntu 22.04 LTS (Jammy)  ← base image Azure endorsée
```

**Règle** : Toujours partir d'une image de base approuvée Azure. Cela garantit le billing tag et l'alignement VHD automatiquement.

### Spécifications VHD obligatoires

| Contrainte | Valeur | Impact si non respecté |
|-----------|--------|----------------------|
| **Architecture** | 64 bits uniquement | Rejet certification |
| **Taille OS disk** | 1 GB à 2 024 GB (recommandé 30-50 GB) | Rejet ou coût élevé |
| **1er MB libre** | 2 048 premiers secteurs vides (Azure metadata) | Rejet certification |
| **VHD aligné** | Taille virtuelle = multiple de 1 MB | Rejet certification |
| **Type disque** | Page blob (non block blob) | Rejet certification |
| **Données persistantes** | Ne pas stocker sur OS disk | Perte données clients |
| **Data disks** | Tous les plans = même nombre de data disks | Rejet certification |

**Pour SMW** : La base de données MySQL, les uploads MediaWiki et les logs Apache/PHP doivent être sur un **data disk dédié** de 128 GB, pas sur le disque OS.

### Généralisation obligatoire

Toute image soumise à Marketplace doit être **généralisée** (déprovisionning des identifiants d'instance) :

```bash
# Dernière étape du provisioner Packer — OBLIGATOIRE
# packer/provisioners/08-cleanup-generalize.sh
sudo waagent -deprovision+user -force
```

Dans le template Packer (`smw-vm.pkr.hcl`) :

```hcl
provisioner "shell" {
  inline = ["sudo /usr/sbin/waagent -force -deprovision+user"]
  execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo '{{ .Path }}'"
}
```
### SecurityType Azure Compute Gallery — Exigence TrustedLaunch

> ⚠️ **Exigence critique pour la visibilité dans Partner Center.**
> Partner Center ne liste dans son dropdown "Gallery image" que les image definitions
> ayant `SecurityType = TrustedLaunch`. Une definition avec `TrustedLaunchSupported`
> est **silencieusement absente** du dropdown.

#### Problème rencontré (2026-05-17)

La gallery `galSMWMarketplace` était initialement créée avec l'image definition
`smw-knowledge-base` configurée en `SecurityType = TrustedLaunchSupported`.
Cette valeur est le défaut de la commande `az sig image-definition create` lorsque
le paramètre `--features` n'est pas spécifié.

**Symptôme** : `galSMWMarketplace / smw-knowledge-base` était invisible dans le
dropdown "Gallery image" du Partner Center Technical Configuration, alors que
`galDSpaceMarketplace` (configurée en `TrustedLaunch`) apparaissait normalement.

| Gallery | SecurityType | Visible Partner Center |
|---------|-------------|----------------------|
| `galDSpaceMarketplace` | `TrustedLaunch` | ✅ OUI |
| `galSMWMarketplace` (avant fix) | `TrustedLaunchSupported` | ❌ NON |
| `galSMWMarketplace` (après fix) | `TrustedLaunch` | ✅ OUI |

#### Fix exécuté (2026-05-17)

La correction a nécessité la suppression complète de l'image definition et de toutes
ses versions, puis leur recréation avec `--features "SecurityType=TrustedLaunch"` :

```bash
# 1. Supprimer toutes les versions (6.0.20260511, 6.0.20260512, 6.0.20260514, 6.0.20260517)
az sig image-version delete --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace --gallery-image-definition smw-knowledge-base \
  --gallery-image-version <version>

# 2. Supprimer l'image definition (TrustedLaunchSupported)
az sig image-definition delete --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace --gallery-image-definition smw-knowledge-base

# 3. Recréer avec SecurityType=TrustedLaunch (OBLIGATOIRE)
az sig image-definition create \
  --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace \
  --gallery-image-definition smw-knowledge-base \
  --publisher cotechnoe --offer smw-knowledge-base --sku standard \
  --os-type Linux --hyper-v-generation V2 \
  --features "SecurityType=TrustedLaunch"

# 4. Recréer la version depuis la managed image intermédiaire
az sig image-version create \
  --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace \
  --gallery-image-definition smw-knowledge-base \
  --gallery-image-version 6.0.20260517 \
  --managed-image "...tmp-smw-knowledge-base-6.0.1-20260517" \
  --target-regions canadacentral
```

**Vérification finale** :
```bash
az sig image-definition list \
  --resource-group rg-smw-marketplace \
  --gallery-name galSMWMarketplace \
  --query "[].{Name:name, SecurityType:features[?name=='SecurityType'].value|[0], HyperVGen:hyperVGeneration, State:provisioningState}" \
  -o table
# Résultat : smw-knowledge-base | TrustedLaunch | V2 | Succeeded ✅
```

#### Prévention des régressions

| Action | Prévention |
|--------|-----------|
| **Nouveau build Packer** | L'image definition est pré-existante — aucune action requise si non recréée |
| **Recréation de la gallery** | Exécuter `make marketplace-gallery-permissions` + recréer la definition avec `--features "SecurityType=TrustedLaunch"` |
| **Nouveau projet / nouvelle gallery** | Toujours passer `--features "SecurityType=TrustedLaunch"` à `az sig image-definition create` |
| **Vérification** | `az sig image-definition list ... --query "features[?name=='SecurityType'].value"` doit retourner `TrustedLaunch` |

> **Note Packer** : Le `SecurityType` de l'image definition n'est pas configurable dans
> `packer/smw-vm.pkr.hcl` — il est fixé à la création de la definition. Le bloc
> `shared_image_gallery_destination` ne contient pas ce paramètre. Voir
> `packer/smw-vm.pkr.hcl` pour le commentaire de prérequis.
---

## 🔒 Décision 3 : Conformité Sécurité (Tests de Certification Linux)

Microsoft exécute une suite de tests automatisés sur chaque image. **Échec = rejet automatique.**

### Exigences obligatoires à implémenter dans les provisioners Packer

| Test Microsoft | Exigence | Script Packer |
|---------------|----------|---------------|
| **Azure Linux Agent** | `walinuxagent` installé, version récente | `07-security-harden.sh` |
| **Provisioning agent** | `cloud-init` recommandé | inclus Ubuntu 22.04 LTS |
| **Kernel params** | `console=ttyS0 earlyprintk=ttyS0 rootdelay=300` (x86_64) | vérifier `/proc/cmdline` |
| **Driver réseau** | `hv_netvsc` (Hyper-V Network VSC) obligatoire | `lsmod \| grep hv_netvsc` |
| **Boot disks** | Doit démarrer sur Premium SSD, Standard SSD et disques éphémères | Testé via Packer |
| **LVM** | **Non recommandé** sur disque OS | Partitionnement simple |
| **CVE critiques** | **Zéro CVE critique** au moment de la certification | `apt-get upgrade` récent |
| **Bash history** | Effacé avant capture image | `08-cleanup-generalize.sh` |
| **verify_no_pre_exist_users** | Aucun mot de passe ni clé SSH pour les users | Utilisateurs système sans password |
| **Partition swap** | Pas de swap sur disque OS | Vérifier fstab |
| **Root unique** | Une seule partition root sur OS disk | Vérifier partitionnement |
| **OpenSSL** | v0.9.8+ (Ubuntu 22.04 ≥ 3.x : ✅) | — |
| **Python** | 2.6+ pour extensions VM | `python3` inclus Ubuntu |
| **ClientAliveInterval SSH** | Valeur 0 à 235 | `07-security-harden.sh` |
| **TLS 1.0 / 1.1** | **Désactivés** obligatoirement | `07-security-harden.sh` |
| **TLS 1.2+** | **Activé** obligatoirement | idem |
| **DNS** | `ping bing.com` doit réussir depuis la VM | Vérifier NSG sortant |
| **VM extensions** | La VM doit supporter les extensions Azure | `walinuxagent` requis |

### Clarification : Utilisateurs système dans l'image (verify_no_pre_exist_users)

Le test `verify_no_pre_exist_users` de Microsoft vérifie uniquement :
> "*Password of user XXXX is detected when the password or key of a user is detected.*"

**Ce qui est interdit dans l'image :**
- Utilisateurs avec **mot de passe** configuré (hash dans `/etc/shadow`)
- Utilisateurs avec **clés SSH** (`~/.ssh/authorized_keys`)

**Ce qui est AUTORISÉ dans l'image :**
- **Utilisateurs système** sans mot de passe (`!` ou `*` dans `/etc/shadow`)
- Utilisateurs avec shell non-interactif (`/sbin/nologin` ou `/bin/false`)
- Utilisateurs sans fichier `authorized_keys`

**Implémentation SMW** : L'utilisateur `www-data` (Apache/PHP-FPM) et `mysql` sont créés automatiquement par `apt install apache2` et `apt install mysql-server` — aucun mot de passe configuré, shell non-interactif. Ces utilisateurs passent la certification.

### Script `packer/provisioners/configure-ssh.sh`

```bash
#!/usr/bin/env bash
# Configuration SSH conforme aux exigences Microsoft Marketplace
set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"

echo "[INFO] Configuration SSH pour conformité Marketplace"

# ClientAliveInterval entre 0 et 235 (obligatoire)
sudo sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 120/' "$SSHD_CONFIG"
# Désactiver root login
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
# Désactiver auth par mot de passe (clés SSH uniquement)
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"

sudo systemctl restart sshd
echo "[INFO] SSH configuré (ClientAliveInterval=120, PermitRootLogin=no)"
```

### Script `packer/provisioners/configure-tls.sh` (inclus dans 07-security-harden.sh)

```bash
# Désactiver TLS 1.0 et 1.1 dans Apache
cat >> /etc/apache2/mods-available/ssl.conf << 'EOF'
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
SSLHonorCipherOrder on
EOF

# Désactiver TLS 1.0/1.1 dans OpenSSL système
if ! grep -q "MinProtocol" /etc/ssl/openssl.cnf; then
    cat >> /etc/ssl/openssl.cnf << 'EOF2'

[system_default_sect]
MinProtocol = TLSv1.2
CipherString = DEFAULT@SECLEVEL=2
EOF2
fi
```

### Ordre des provisioners dans `smw-vm.pkr.hcl`

```hcl
build {
  sources = ["source.azure-arm.smw_vm"]

  # 1. Stack SMW
  provisioner "shell" { script = "packer/provisioners/01-install-base.sh" }
  provisioner "shell" { script = "packer/provisioners/02-install-php.sh" }
  provisioner "shell" { script = "packer/provisioners/03-install-apache.sh" }
  provisioner "shell" { script = "packer/provisioners/04-install-mysql.sh" }
  provisioner "shell" { script = "packer/provisioners/05-install-mediawiki.sh" }
  provisioner "shell" { script = "packer/provisioners/06-install-smw.sh" }

  # 2. Conformité Marketplace
  provisioner "shell" { script = "packer/provisioners/07-security-harden.sh" }

  # 3. Nettoyage et généralisation — TOUJOURS EN DERNIER
  provisioner "shell" { script = "packer/provisioners/08-cleanup-generalize.sh" }
  provisioner "shell" {
    inline          = ["sudo /usr/sbin/waagent -force -deprovision+user"]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo '{{ .Path }}'"
  }
}
```

---

## 💰 Décision 4 : Modèle de Licence

**Décision** : **Usage-based — Per vCPU — $0.07 USD / vCPU / heure**

| Option considérée | Décision | Justification |
|-------------------|----------|---------------|
| BYOL/Free | ❌ Écarté | Pas de retour monétaire — ne permet pas de financer support et maintenance |
| Flat rate | ❌ Écarté | Peu équitable — pénalise les petites organisations avec de petites VMs |
| **Per vCPU** | ✅ **Retenu** | Prix proportionnel à la taille de VM choisie — standard du Marketplace VM |
| Per vCPU size | ❌ Écarté | Trop complexe à maintenir (une entrée par taille de VM) |

**Tarif retenu :**

```
$0.07 USD / vCPU / heure
```

**Impact client selon la taille de VM :**

| VM Size | vCPU | RAM | Frais logiciel/h | Frais logiciel/mois (~730h) |
|---------|------|-----|------------------|--------------------------|
| Standard_D2s_v3 *(minimum SMW)* | 2 | 8 GB | $0.14/h | ~$102/mois |
| Standard_D4s_v3 *(recommandée)* | 4 | 16 GB | $0.28/h | ~$204/mois |
| Standard_D8s_v3 | 8 | 32 GB | $0.56/h | ~$409/mois |

> Ces montants s'ajoutent au coût Azure de la VM (compute, disque, réseau).

**Justification du positionnement $0.07/vCPU :**
- SMW est une stack complète (MediaWiki + SMW + Apache + PHP-FPM + MySQL) avec configuration Azure prête à l'emploi — valeur ajoutée pour les organisations
- Permet un essai gratuit de 1 mois pour faciliter l'adoption
- Financement du support, de la maintenance des images et des mises à jour de certification
- Microsoft collecte et reverse les paiements (moins ~3% de commission agency fee)
- Licence GPL-2.0 (MediaWiki + SMW) — modèle usage-based conforme à la licence open source

---

## 📝 Décision 5 : Contenu du Listing (Partner Center)

### Identifiants offre

```
Offer ID   : smw-knowledge-base       ← IMMUABLE après création
Offer Name : SMW Knowledge Base
```

### Champs obligatoires

| Champ | Contenu cible |
|-------|--------------|
| **Titre** | "Semantic MediaWiki — Knowledge Base on Azure" |
| **Summary** | **Max 100 caractères** — Ex: "Semantic MediaWiki knowledge base with structured data, ontologies, and SPARQL queries on Azure." |
| **Description** | 2-3 paragraphes : (1) qu'est-ce que SMW, (2) valeur pour organisations gérant des connaissances structurées, (3) ce que l'image fournit |
| **Keywords** | **Max 20 mots-clés** — Ex: `MediaWiki`, `Semantic MediaWiki`, `SMW`, `knowledge base`, `wiki`, `ontology`, `SPARQL`, `structured data`, `linked data`, `open-source`, `knowledge management` |
| **Logo Small** | 48×48 px PNG |
| **Logo Medium** | 90×90 px PNG |
| **Logo Large** | 216×216 à 350×350 px PNG (**obligatoire**) |
| **Screenshots** | Max 5, résolution **1280×720 px PNG** (MediaWiki UI, page sémantique, SMW Special:Browse) — inclure les mots-clés dans les noms de fichiers |
| **Vidéo** | 60-90 secondes — le **client** comme héros (adresser les défis principaux) — inclure les mots-clés dans le titre de la vidéo |
| **Documents** | PDF uniquement (livres blancs, guides, présentations) — ajouter l'URL de landing page avec UTM params |
| **Catégories** | "Analytics" (primaire), "Developer Tools" (secondaire) |
| **Industries** | "Education", "Research", "Government" |
| **Support URL** | GitHub Issues ou site support |
| **Support email** | Obligatoire |
| **Privacy policy URL** | URL publique (GitHub ou site) |
| **Terms of use** | GPL-2.0 URL : `https://www.gnu.org/licenses/old-licenses/gpl-2.0.html` |

### Customer leads

Configurer une destination de leads dans Partner Center :
- Option la moins contraignante : **Azure Table Storage** (créer une Storage Account dédiée)
- Alternative : **HTTPS endpoint** via Azure Function ou Logic App

---

## 📊 Décision 6 : Plans VM

### Structure recommandée

```
Offer: smw-knowledge-base
 └── Plan: standard
       ├── Plan name: Semantic MediaWiki Standard
       ├── Modèle: Usage-based — Per vCPU
       ├── Prix: $0.07 USD / vCPU / heure
       ├── Essai gratuit: 1 mois (optionnel, recommandé pour adoption)
       ├── VM sizes recommandées: Standard_D2s_v3 (2 vCPU, 8 GB RAM minimum SMW)
       ├── OS disk: 50 GB (Ubuntu 22.04 LTS)
       ├── Data disk: 1 × 128 GB (MySQL + uploads + logs)
       └── Regions: Tous marchés (Canada Central prioritaire)
```

> ⚠️ **Le modèle de prix (per vCPU) ne peut PAS être modifié après la première publication.**

**Règle importante** : Tous les plans d'une offre doivent avoir le **même nombre de data disks** dans leurs images.

---

## 🧪 Décision 7 : Preview Audience et Validation

Avant publication live, configurer une **Preview Audience** (Azure subscription IDs) pour valider l'offre en conditions réelles :

```bash
# Partner Center > Preview audience
# Ajouter les subscription IDs des environnements de test :
# - Subscription de dev (cotechnoe)
# - Subscription de staging (si différente)
```

**Validation manuelle requise avant "Go Live"** :
- [ ] Déployer depuis le Marketplace preview → VM démarre correctement
- [ ] MediaWiki accessible via HTTPS port 443
- [ ] Redirect HTTP 80 → HTTPS 301 fonctionnel
- [ ] SMW fonctionnel (Special:Browse accessible)
- [ ] `make vm-smoke-test` passe

---

## 🔬 Décision 8 : Tests de Certification et SAS URI

### Outil de certification Microsoft

Microsoft fournit le [Certification Test Tool for Azure VMs](https://aka.ms/AzureCertificationTestTool) (CTT) pour valider localement une image **avant** soumission au Partner Center.

**Intégration dans le workflow :**

```bash
# Target Makefile (ADR-602)
marketplace-validate: ## Exécuter les tests de certification locaux
@echo "Téléchargement Certification Test Tool..."
@wget -q https://aka.ms/AzureCertificationTestTool -O ctt.zip
@unzip -o ctt.zip -d /tmp/ctt
@echo "Exécution tests sur image $(IMAGE_DEFINITION)..."
@/tmp/ctt/AzureCertificationTestTool --image $(IMAGE_DEFINITION)
```

### Exigences SAS URI pour certification

Pour soumettre une image VHD au Partner Center, un **SAS URI** valide est requis :

| Exigence SAS URI | Valeur |
|-----------------|--------|
| **Durée de validité** | Minimum 3 semaines après soumission |
| **Permissions** | `Read` uniquement (pas de `Write` ni `Delete`) |
| **Container** | Blob storage avec le VHD généré |
| **Format URL** | `https://<storage>.blob.core.windows.net/<container>/<vhd>?sv=...&sig=...` |

**Script génération SAS URI :**

```bash
#!/usr/bin/env bash
# scripts/generate-vhd-sas-uri.sh
set -euo pipefail

STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-stsmwmarketplace}"
CONTAINER="${CONTAINER:-vhds}"
VHD_NAME="${VHD_NAME:-smw-vm.vhd}"
EXPIRY=$(date -u -d "+30 days" '+%Y-%m-%dT%H:%MZ')

echo "[INFO] Génération SAS URI pour $VHD_NAME (expiration: $EXPIRY)"
az storage blob generate-sas \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER" \
  --name "$VHD_NAME" \
  --permissions r \
  --expiry "$EXPIRY" \
  --https-only \
  --output tsv
```

### Checklist pré-soumission

- [ ] `make marketplace-validate` passe sans erreurs
- [ ] SAS URI généré avec expiration > 3 semaines
- [ ] VHD accessible via le SAS URI (test `curl -I`)
- [ ] Aucune CVE critique détectée (`apt-get upgrade` récent)
- [ ] Image généralisée (`waagent -deprovision+user` exécuté)
- [ ] Bash history vidé (< 1 KB)
- [ ] TLS 1.0/1.1 désactivés dans Apache et OpenSSL

---

## 🔗 Impact sur les autres ADRs

| ADR | Modification requise |
|-----|---------------------|
| [ADR-600](./600-DEVOPS-bootstrap-configuration-management.md) | Ajouter variables `MARKETPLACE_PUBLISHER_ID`, `OFFER_ID`, `IMAGE_GALLERY` dans `env/.env.dev` |
| [ADR-602](./602-DEVOPS-makefile-orchestrateur.md) | Ajouter targets: `make marketplace-gallery-permissions`, `make marketplace-validate`, `make marketplace-publish` |
| [ADR-613](./613-DEVOPS-provisioner-architecture-validation.md) | Séquence provisioners 01–08 documentée, `smw-vm.pkr.hcl` |

### Variables à ajouter dans `env/.env.dev` (ADR-600)

```bash
# === Azure Marketplace ===
MARKETPLACE_PUBLISHER_ID="cotechnoe"
OFFER_ID="smw-knowledge-base"
PLAN_ID="standard"
PLAN_PRICE_PER_VCPU="0.07"             # USD / vCPU / heure
IMAGE_GALLERY="galSMWMarketplace"
IMAGE_DEFINITION="smw-vm"
VM_GEN="V2"                            # Gen2 requis pour Ubuntu 22.04

# Storage pour Customer Leads
LEADS_STORAGE_ACCOUNT="stsmwmarketplaceleads"
LEADS_TABLE_NAME="MarketplaceLeads"
```

---

## ⚖️ Conséquences

### ✅ Positives

| Bénéfice | Description |
|----------|-------------|
| **Certification garantie** | Respect total des exigences = pas de rejet surprise |
| **Sécurité renforcée** | TLS 1.2+, no default credentials, SSH hardened = image production-ready |
| **Revenus** | $0.07/vCPU/h finance support, maintenance images et certification |
| **Distribution CSP** | Usage-based = éligible CSP program, distribution via partenaires Microsoft |
| **Traçabilité** | Chaque exigence mappée vers un script Packer versionné |

### ⚠️ Contraintes et Risques

| Risque | Mitigation |
|--------|------------|
| Tenant Entra unique requis | Vérifier alignment dès création du compte Partner Center |
| `waagent -deprovision+user` irréversible | Toujours exécuter sur une copie, jamais sur la VM de dev |
| Offer ID immuable après création | Offer ID: `smw-knowledge-base` — à valider avant création dans Partner Center |
| Prix per vCPU immuable après publication | Valider $0.07/vCPU/h avant le premier publish live |
| Data disk count identique dans tous les plans | Standardiser à 1 data disk (128 GB) dès le départ |
| Bash history > 1 KB = rejet | `08-cleanup-generalize.sh` doit toujours être la pénultième étape Packer |

---

## � Décision 9 : Stratégie GTM Post-Publication

> **Source** : [GTM Best Practices](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/gtm-best-practices) et [Microsoft Marketplace GTM Toolkit](https://partner.microsoft.com/en-US/asset/collection/microsoft-marketplace-gtm-toolkit#/)

La certification et la publication live ne sont que la **première étape**. La visibilité dans le Marketplace exige une stratégie active de promotion post-publication.

### 9.1 — Optimisation du Listing

**Décision** : Le listing doit respecter les recommandations Microsoft en matière de présentation avant tout "Go Live".

| Élément | Règle SMW | Source |
|---------|-----------|--------|
| **Titre** | "Semantic MediaWiki — Knowledge Base on Azure" — inclure les termes de recherche (wiki, knowledge base, semantic) | GTM best practices |
| **Description** | Commencer par la proposition de valeur (2 premières phrases = extraits de recherche) | GTM best practices |
| **Logo app details** | PNG 216×216 à 350×350 px (obligatoire) | GTM best practices |
| **Logo search** | 48×48 px PNG — généré automatiquement par Partner Center depuis le grand logo | GTM best practices |
| **Screenshots** | Max 5 × 1280×720 px PNG — noms de fichiers incluant des mots-clés (`smw-browse-ontology.png`) | GTM best practices |
| **Vidéo** | 60-90 secondes — le **client** comme héros (pas l'éditeur), adresser les problèmes/objectifs principaux | GTM best practices |
| **Documents "Learn more"** | Format PDF (livres blancs, guides d'usage) — éduquer, ne pas vendre ; ajouter URL landing page + UTM params | GTM best practices |

> ⚠️ Les champs `Logo Small (48×48)` et `Logo Medium (90×90)` ne doivent **pas** avoir de fond transparent. Utiliser fond blanc ou couleur de marque.

### 9.2 — GTM Toolkit : Assets Post-Publication

Après le premier "Go Live", utiliser les ressources officielles Microsoft pour promouvoir la disponibilité de l'offre :

| Asset | Usage | Téléchargement |
|-------|-------|---------------|
| **Available on Microsoft Marketplace badge** | Ajouter sur README.md, site web, emails | [badges.zip](https://assetsprod.microsoft.com/mpn/en-us/available-on-microsoft-marketplace-badges.zip) |
| **Co-branded social assets** | Posts LinkedIn/Twitter annonçant la disponibilité | [social-assets.zip](https://assetsprod.microsoft.com/mpn/en-us/microsoft-marketplace-co-branded-social-assets.zip) |
| **Co-branded pitch deck** | Présentation partenaires pour achat via Marketplace | [pitchdeck.pptx](https://assetsprod.microsoft.com/mpn/en-us/microsoft-marketplace-cobranded-pitchdeck.pptx) |
| **AI listing optimization** | Analyse et suggestions d'amélioration du listing | [App Advisor](https://www.microsoft.com/en-us/software-development-companies/app-advisor/guidance/my-results?stage=grow&step=optimize-your-listing-with-personalized-recommendations) |

**Règle Trademark** : Utiliser uniquement les badges officiels Microsoft pour mentionner la disponibilité sur Marketplace. Respecter les [Microsoft Trademark and Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general.aspx).

### 9.3 — Campaign Tracking (OCID + UTM)

Tout lien vers le listing Marketplace doit inclure des paramètres de suivi pour mesurer l'efficacité des campagnes :

```
https://azuremarketplace.microsoft.com/en-US/marketplace/apps/cotechnoe.smw-knowledge-base
  ?ocid=<campaign_id>&utm_source=<source>&utm_medium=<medium>&utm_campaign=<campaign>
```

| Paramètre | Obligatoire | Exemple SMW |
|-----------|-------------|-------------|
| `ocid` | ✅ Recommandé | `smw_newsletter_v1`, `smw_github_readme` |
| `utm_source` | ✅ Recommandé | `newsletter`, `linkedin`, `github`, `website` |
| `utm_medium` | ✅ Recommandé | `email`, `social`, `referral`, `cpc` |
| `utm_campaign` | ✅ Recommandé | `v1_launch`, `spring2026`, `partner_promo` |
| `utm_content` | Optionnel | `badge_readme`, `cta_hero`, `footer_link` |
| `utm_term` | Optionnel (payant) | `semantic-mediawiki-azure` |

**Suivi des résultats :**
- Trafic et conversions : [Insights workspace](https://partner.microsoft.com/dashboard/insights/analytics/overview)
- Leads avec tags campagne : [Referrals workspace](https://partner.microsoft.com/dashboard/v2/referrals/v3/leads/marketplace)

### 9.4 — Gestion des Leads

**Décision** : Configurer une destination de leads **avant** le premier "Go Live" — les leads générés pendant la période de preview sont perdus si aucune destination n'est configurée.

| Option | Complexité | Recommandation |
|--------|-----------|----------------|
| **Azure Table Storage** | Faible | ✅ Prioritaire pour SMW (storage account déjà dans `env/`) |
| HTTPS Endpoint (Azure Function) | Moyenne | Alternative si intégration CRM requise |
| CRM direct (Dynamics, Salesforce) | Élevée | À évaluer en phase de croissance |

**Référence** : [Lead management guidance](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/commercial-marketplace-get-customer-leads)

### 9.5 — Checklist GTM

À compléter avant et après chaque publication d'une nouvelle version :

**Avant Go Live :**
- [ ] Logo 216×216–350×350 px PNG validé (fond non transparent)
- [ ] Screenshots 1280×720 px, noms de fichiers avec mots-clés
- [ ] Description avec proposition de valeur dans les 2 premières phrases
- [ ] Destination leads configurée (Azure Table Storage)
- [ ] Support URL testée depuis un navigateur incognito

**Après Go Live (dans les 7 jours) :**
- [ ] Badge "Available on Microsoft Marketplace" ajouté au README.md du dépôt docs
- [ ] Post LinkedIn avec co-branded social asset
- [ ] URL de listing avec paramètres OCID/UTM dans tous les liens marketing
- [ ] Dashboard Insights validé (au moins 1 visite trackée après partage)

---

## �📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-04-16 | @dev-team | Création ADR-800 | Formalisation bonnes pratiques Microsoft Marketplace pour SMW (sources: learn.microsoft.com) |
| 2026-05-17 | @dev-team | Ajout Décision 2 — SecurityType TrustedLaunch | Fix image definition `galSMWMarketplace` invisible dans Partner Center (TrustedLaunchSupported → TrustedLaunch) |
| 2026-06-xx | @dev-team | Ajout Décision 9 GTM | Intégration recommandations officielles Microsoft GTM best practices et GTM Toolkit |

**Référence Certification Policies** : Version 1.67 (August 26, 2024) — https://learn.microsoft.com/en-us/legal/marketplace/certification-policies

**Outil de certification** : Microsoft fournit le [Certification Test Tool for Azure VMs](https://aka.ms/AzureCertificationTestTool) pour valider localement une image avant soumission. À intégrer dans `make marketplace-validate`.

**Contact certification** : En cas d'exception requise (SSH désactivé, template ARM custom), contacter l'équipe via [Certification support](https://forms.office.com/pages/responsepage.aspx?id=v4j5cvGGr0GRqy180BHbR9VNeZknSDxDlxnRDB3pi9BUNkI4UVdGRzZMUUlFVEYySElOQ0VIRVlRQS4u)
