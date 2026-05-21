# Guide — Construction de l'image VM Nextcloud

Ce guide décrit la procédure complète pour construire l'image VM Nextcloud avec
[HashiCorp Packer](https://www.packer.io/) et la publier dans l'Azure Compute Gallery.

---

## Prérequis

### Outils locaux

| Outil | Version minimale | Installation |
|-------|-----------------|--------------|
| [Packer](https://developer.hashicorp.com/packer/install) | 1.10+ | `brew install packer` / apt |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | 2.60+ | `brew install azure-cli` / apt |
| `make` | 3.81+ | fourni par l'OS |
| `shellcheck` (optionnel) | 0.9+ | pour `make lint` |

### Ressources Azure requises

Avant la première construction, les ressources suivantes doivent exister dans votre
abonnement Azure :

- **Resource group de build** : `rg-nextcloud-marketplace-build`
- **Resource group gallery** : `rg-nextcloud-marketplace`
- **Azure Compute Gallery** : `gal_nextcloud_marketplace`
- **Image definition** : `nextcloud-marketplace`

Ces ressources sont créées automatiquement via `make infra-create` (voir [Étape 3](#étape-3--créer-les-ressources-azure)).

---

## Configuration de l'environnement

### 1. Créer le fichier d'environnement

```bash
cp env/.env.example env/.env
```

Remplir `env/.env` avec les valeurs réelles :

```ini
# Authentification Azure — via Azure CLI (az login), aucun secret requis
AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Resource group temporaire pour le build
BUILD_RESOURCE_GROUP=rg-nextcloud-marketplace-build
AZURE_LOCATION=canadacentral

# Azure Compute Gallery — destination de l'image
GALLERY_RESOURCE_GROUP=rg-nextcloud-marketplace
GALLERY_NAME=gal_nextcloud_marketplace
GALLERY_IMAGE_NAME=nextcloud-marketplace
REPLICATION_REGIONS=canadacentral eastus

# Version et environnement
IMAGE_VERSION=0.1.0
ENVIRONMENT=dev
VM_SIZE=Standard_D4s_v3

# Versions des logiciels
NC_VERSION=33.0.3
```

> **Important** : `env/.env` est dans `.gitignore`. Ne jamais le committer.

### 2. S'authentifier à Azure

```bash
make azure-login
```

Ouvre le navigateur pour une connexion interactive. Aucun Service Principal requis.

### 3. Vérifier les variables d'environnement

```bash
make env-check
```

---

## Workflow de construction

### Étape 1 — Créer les ressources Azure

À exécuter **une seule fois** avant le premier build :

```bash
make infra-create
```

Crée en séquence :
1. `rg-nextcloud-marketplace-build` — resource group de build
2. `rg-nextcloud-marketplace` — resource group de la gallery
3. `gal_nextcloud_marketplace` — Azure Compute Gallery
4. `nextcloud-marketplace` — image definition (Linux, Generalized, Hyper-V V2)

### Étape 2 — Initialiser les plugins Packer

À exécuter une seule fois (ou après mise à jour des plugins) :

```bash
make init
```

Cela télécharge le plugin `hashicorp/azure ~> 2` déclaré dans `nextcloud.pkr.hcl`.

### Étape 3 — Valider le template

```bash
make validate
```

Vérifie la syntaxe HCL et la cohérence des variables sans déclencher de build.

### Étape 4 — Linter les scripts shell (optionnel)

```bash
make lint
```

Exécute `shellcheck` sur tous les scripts de `packer/nextcloud/scripts/`.

### Étape 5 — Construire l'image

```bash
make image-build
```

Ou avec une version d'image spécifique :

```bash
make image-build IMAGE_VERSION=1.0.0
```

**Durée estimée** : ~15–20 minutes (`Standard_D4s_v3`, `canadacentral`).

À la fin du build, Packer génère un `packer-manifest.json` dans `packer/nextcloud/`
avec les métadonnées de l'image publiée.

---

## Variables configurables

Les valeurs par défaut sont définies dans `packer/nextcloud/variables.pkr.hcl`.
Elles peuvent être surchargées via `env/.env` ou en ligne de commande avec `-var`.

| Variable | Défaut | Description |
|----------|--------|-------------|
| `nc_version` | `33.0.3` | Version de Nextcloud à installer |
| `php_version` | `8.3` | Version PHP (via PPA ondrej/php) |
| `postgresql_version` | `16` | Version PostgreSQL (PGDG) |
| `vm_size` | `Standard_D4s_v3` | Taille de la VM de build |
| `location` | `canadacentral` | Région Azure principale |
| `environment` | `dev` | Tag d'environnement (`dev`/`staging`/`prod`) |
| `image_version` | `0.1.0` | Version sémantique de l'image dans la gallery |

---

## Séquence des provisioners

Le build exécute 14 provisioners dans l'ordre suivant :

| # | Script | Rôle |
|---|--------|------|
| — | `lib/` (file) | Copie la bibliothèque partagée `log.sh` |
| — | `config/` (file) | Copie les fichiers de configuration |
| 00 | `00-system-prepare.sh` | Mise à jour système, locale, timezone |
| 01 | `01-install-nginx.sh` | Installation NGINX depuis les dépôts Ubuntu |
| 02 | `02-install-php.sh` | PHP-FPM + extensions via PPA `ondrej/php` |
| 03 | `03-install-postgresql.sh` | PostgreSQL depuis le dépôt PGDG officiel |
| 04 | `04-install-redis.sh` | Redis depuis les dépôts Ubuntu |
| 05 | `05-install-nextcloud.sh` | Téléchargement et vérification SHA-256 de Nextcloud |
| 06 | `06-configure-nginx.sh` | Déploiement du vhost Nextcloud |
| 07 | `07-configure-php.sh` | Configuration du pool PHP-FPM |
| 08 | `08-configure-postgresql.sh` | Initialisation de la base de données |
| 09 | `09-configure-redis.sh` | Configuration Redis avec authentification |
| 10 | `10-configure-nextcloud.sh` | Permissions et structure de répertoires |
| 11 | `11-configure-security.sh` | UFW, fail2ban, mises à jour automatiques |
| 12 | `12-configure-services.sh` | Cron Nextcloud et services systemd |
| 99 | `99-sysprep.sh` | Déprovision waagent, nettoyage Azure |

---

## Build en mode debug

Pour diagnostiquer une erreur de provisioning :

```bash
make image-build-debug
```

Active `PACKER_LOG=1` et `-on-error=ask` : en cas d'échec, Packer s'arrête et laisse
la VM accessible en SSH pour investigation. Voir
[ADR 618](../adr/618-DEVOPS-strategie-debug-post-image-vm.md) pour la procédure complète.

---

## Critères de succès

### Succès du build Packer

Le build est considéré réussi lorsque Packer affiche un exit code 0 et la ligne :

```
Build 'nextcloud.azure-arm.nextcloud' finished after X minutes Y seconds.
```

Vérifier que la version cible est bien publiée dans la Compute Gallery :

```bash
make gallery-check
```

Résultat attendu (JSON) :

```json
{
  "version": "0.1.2",
  "state": "Succeeded",
  "replicationState": null
}
```

Le fichier `packer/nextcloud/packer-manifest.json` est également généré avec les
métadonnées de l'artefact publié.

### Vérification post-déploiement (VM de test)

Déployer une VM de test depuis la version d'image publiée, puis lancer les deux
suites de vérification gérées par le Makefile.

#### Tests HTTP/HTTPS (depuis le poste de développement)

```bash
NEXTCLOUD_HOST=<ip_ou_fqdn> make test
```

Vérifie : redirection HTTP → HTTPS, code 200 sur `/login`, `status.php`
(`installed=true`, `maintenance=false`), redirections DAV, en-têtes de sécurité.

Résultat attendu : `X passed, 0 failed`.

#### Vérification des services internes (via SSH dans la VM)

```bash
make vm-check VM_SSH=azureuser@<ip>
```

Le script `tests/check-services.sh` est envoyé à la VM via SSH et vérifie :

| Composant | Critère |
|-----------|---------|
| OS | Ubuntu 24.04 LTS |
| Services | `nginx`, `php8.3-fpm`, `postgresql`, `redis-server` → `active` |
| PHP CLI | 8.3.x |
| PHP-FPM | 8.3.x |
| PostgreSQL | 16.x + base `nextcloud` présente |
| Redis | `PONG` |
| Nextcloud | `version.php` présent, propriétaire `www-data:www-data` |
| UFW | actif |
| fail2ban | ≥ 1 jail actif |

Résultat attendu : `X passé(s), 0 échoué(s)`.

---

## Problèmes connus

### PHP 8.5 CLI installé par des méta-paquets transitifs

Les paquets `php-imagick`, `php-redis` et `php-smbclient` tirent `php8.5-cli` comme
dépendance transitive (méta-paquet sans version fixe). Le script `02-install-php.sh`
corrige cela automatiquement après l'installation :

```bash
update-alternatives --set php "/usr/bin/php${PHP_VERSION}"
```

Vérification : `php --version` → `8.3.x`. PHP-FPM n'est pas affecté.

### Avertissement non-fatal — truncate sur le log PostgreSQL (étape 99)

Le fichier `/var/log/postgresql/postgresql-16-main.log` est détenu par `postgres:adm`
(mode 640) et ne peut pas être tronqué par l'utilisateur Packer. Le build réussit
malgré cet avertissement :

```
truncate: cannot open '/var/log/postgresql/postgresql-16-main.log' for writing: Permission denied
```

Impact : le log PG subsiste dans l'image finale (contenu inoffensif). Correction
prévue dans la prochaine version.

---

## Mettre à jour les versions logicielles

### Nextcloud

1. Vérifier la dernière version stable sur [download.nextcloud.com](https://download.nextcloud.com/server/releases/)
2. Mettre à jour `nc_version` dans `packer/nextcloud/variables.pkr.hcl`
3. Mettre à jour `NC_VERSION` dans `env/.env`
4. Lancer `make image-build IMAGE_VERSION=<nouvelle_version>`

### PHP / PostgreSQL

Modifier `php_version` ou `postgresql_version` dans `variables.pkr.hcl`.
Les scripts de provisioning utilisent ces variables — aucune modification de script requise.

---

## Résolution de problèmes courants

### `packer init` échoue — plugin introuvable

```
Error: Failed to install provider
```

Vérifier la connectivité réseau et que la version `~> 2` du plugin `hashicorp/azure`
est disponible sur `releases.hashicorp.com`.

### Timeout SSH pendant le build

Le timeout SSH est de 20 minutes (`ssh_timeout = "20m"`). Si le build dépasse ce délai
sur l'étape 00 (mise à jour système), c'est souvent dû à un miroir apt lent.
Utiliser `make image-build-debug` pour identifier l'étape bloquante.

### Échec de vérification SHA-256 (étape 05)

```
sha256sum: WARNING: 1 computed checksum did NOT match
```

La version dans `NC_VERSION` ne correspond pas au fichier téléchargé, ou le miroir
Nextcloud est temporairement incohérent. Vérifier que `nc_version` correspond à une
version publiée sur `download.nextcloud.com`.

### `redis-cli ping` échoue (étape 09)

Le mot de passe `requirepass` dans `config/redis/redis-nextcloud.conf` est un
placeholder (`PLACEHOLDER_REDIS_PASSWORD`). Il est remplacé au premier démarrage
par le script `cloud-init`. Ce comportement est normal pendant le build.

### Permissions insuffisantes sur la gallery

```
AuthorizationFailed: does not have authorization to perform action
```

L'identité connectée via `az login` doit avoir le rôle `Contributor` à la fois sur le
resource group de build et sur le resource group de la gallery. Vérifier avec :

```bash
az ad signed-in-user show --query id -o tsv | xargs -I{} \
  az role assignment list --assignee {} --output table
```

---

## Références

### Documentation externe

#### Azure Marketplace
- [Vue d'ensemble des offres VM sur Azure Marketplace](https://learn.microsoft.com/azure/marketplace/marketplace-virtual-machines)
- [Certification des images VM pour Azure Marketplace](https://learn.microsoft.com/azure/marketplace/azure-vm-image-test)
- [Azure Compute Gallery — documentation](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery)
- [Plugin Packer hashicorp/azure](https://developer.hashicorp.com/packer/integrations/hashicorp/azure)

#### HashiCorp Packer
- [Documentation Packer](https://developer.hashicorp.com/packer/docs)
- [Installation de Packer](https://developer.hashicorp.com/packer/install)
- [Référence HCL2 — blocs `source`, `build`, `variable`](https://developer.hashicorp.com/packer/docs/templates/hcl_templates)
- [Builder `azure-arm`](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)

#### Nextcloud
- [Releases Nextcloud (sources officielles)](https://download.nextcloud.com/server/releases/)
- [Notes de version Nextcloud](https://nextcloud.com/changelog/)
- [Documentation d'installation Nextcloud](https://docs.nextcloud.com/server/latest/admin_manual/installation/)
- [Configuration recommandée — PHP, PostgreSQL, Redis](https://docs.nextcloud.com/server/latest/admin_manual/installation/system_requirements.html)

### ADR internes

- [ADR 617 — Packer outil de construction d'images VM](../adr/617-DEVOPS-packer-outil-construction-images-vm.md)
- [ADR 614 — Workflow d'itération VM de développement](../adr/614-DEVOPS-dev-vm-iteration-workflow.md)
- [ADR 618 — Stratégie de debug post-image VM](../adr/618-DEVOPS-strategie-debug-post-image-vm.md)
- [ADR 616 — Cache Blob Storage pour packages Packer](../adr/616-DEVOPS-blob-storage-cache-packages-packer.md)
- [ADR 602 — Makefile comme orchestrateur](../adr/602-DEVOPS-makefile-orchestrateur.md)
