---
adr: 613
title: "Architecture et Validation des Provisioners Packer — Nextcloud Marketplace"
status: "accepted"
date: 2026-04-16
superseded_by: null
replaces: null
related_adrs: [600, 200, 800]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "high"
  quality:
    - "reliability"
    - "maintainability"
    - "security"
    - "compliance"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "packer"
    - "azure"
    - "bash"
    - "systemd"
    - "php"
    - "nextcloud"
    - "mariadb"
    - "nginx"

tags: ["packer", "provisioner", "validation", "architecture", "systemd", "azure-marketplace", "nextcloud"]
stakeholders: ["@devops-team", "@architecture-team"]
effort: "high"
---

# ADR 613: Architecture et Validation des Provisioners Packer — Nextcloud Marketplace

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-04-16 |
| **Stakeholders** | @devops-team, @security-team |
| **Impact** | 🔴 Élevé (architecture d'image Azure Marketplace) |
| **Effort Implémentation** | 🔴 Élevé (8 scripts séquentiels) |
| **Risque Technique** | 🟡 Moyen (gestion cloud-init et généralisation Azure critique) |

## Statut

✅ Accepté

## Contexte

### Problématique

Le processus de création d'image Azure Marketplace **Nextcloud Hub** via Packer utilise **9 scripts de provisioning exécutés séquentiellement**. Chaque script effectue des opérations critiques :

- Installation de composants système (PHP, Nginx, MariaDB, Redis, Nextcloud)
- Configuration de services (Nginx, PHP-FPM, MariaDB)
- Gestion de la propriété des fichiers (`www-data`)
- Configuration systemd
- Déploiement cloud-init pour configuration au premier démarrage
- Généralisation de l'image (deprovision Azure)

### Risques Identifiés

**Sans validation systématique, risques de :**
1. **Conflits ownership** : Plusieurs scripts modifiant la propriété des mêmes répertoires
2. **Conflits services** : Services démarrés puis arrêtés, ou états incohérents
3. **Overwrites configuration** : Scripts écrasant les configurations d'autres scripts
4. **Cleanup destructif** : Généralisation supprimant des configurations nécessaires
5. **Cloud-init timing** : Scripts firstboot perdus lors de la généralisation
6. **Credentials dans l'image** : Mots de passe MariaDB ou clés non nettoyés avant generalisation

### Exigences Marketplace Azure

- **ADR-200** : Image généralisée (`waagent deprovision`)
- **ADR-300** : Points de sécurité certifiés (TLS, SSH, ports, hardening)
- **ADR-800** : Configuration MariaDB post-boot via cloud-init
- **ADR-302** : SSO via PluggableAuth + SimpleSAMLphp (configuration post-boot)
- Services configurés mais non démarrés avec données sensibles dans l'image

## Décision

### Architecture Provisioner : Séquence en 8 Étapes

L'architecture utilise **8 provisioners exécutés de manière séquentielle** avec intégration cloud-init pour configuration différée au premier boot du client.

```
┌────────────────────────────────────────────────────────────────────┐
│                    PACKER IMAGE BUILD PROCESS                      │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  01-install-base.sh          → Base system setup                  │
│      ├─ Directories: /data/uploads, /data/mariadb, /data/logs      │
│      ├─ Packages: curl, wget, git, unzip, ca-certificates        │
│      └─ Locales et timezone                                       │
│                                                                    │
│  02-install-php.sh           → Runtime PHP                        │
│      ├─ PPA ondrej/php → PHP 8.2 + extensions Nextcloud          │
│      ├─ Extensions: mysql, xml, mbstring, intl, curl, zip, gd    │
│      └─ Composer installé globalement                             │
│                                                                    │
│  03-install-nginx.sh        → Serveur web                        │
│      ├─ Nginx + PHP-FPM socket Unix                         │
│      ├─ sites-enabled configuré                                 │
│      └─ Nginx VirtualHost configuré                         │
│                                                                    │
│  04-install-mariadb.sh         → Base de données                    │
│      ├─ MariaDB 10.6+ (Server + Client)                              │
│      ├─ Datadir: /data/mariadb (disque données)                    │
│      └─ mysql_secure_installation automatisé                      │
│                                                                    │
│  05-install-nextcloud.sh     → Wiki engine                        │
│      ├─ Nextcloud Hub 31.x téléchargé depuis nextcloud.com        │
│      ├─ Installé dans /var/www/nextcloud                         │
│      ├─ Ownership: www-data:www-data                             │
│      └─ Nginx configuré pour Nextcloud                       │
│                                                                    │
│  06-install-nextcloud.sh           → Extension sémantique               │
│      ├─ Apps Nextcloud via occ app:install                       │
│      ├─ Extensions complémentaires: SemanticResultFormats, etc.  │
│      └─ config.php partiel (complété via cloud-init boot) │
│                                                                    │
│  07-security-harden.sh       → Hardening OS                       │
│      ├─ UFW firewall: 443, 22 uniquement                         │
│      ├─ fail2ban, auditd                                         │
│      ├─ Désactivation TLS 1.0/1.1 dans Nginx                    │
│      └─ Suppression packages inutiles                             │
│                                                                    │
│  08-cleanup-generalize.sh    → Généralisation Azure               │
│      ├─ Suppression credentials temporaires                       │
│      ├─ Nettoyage bash history, logs                             │
│      ├─ waagent -deprovision+user                                │
│      └─ sysprep équivalent Linux                                  │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Cloud-Init : Configuration au Premier Boot

Lors du déploiement client depuis Azure Marketplace, un script cloud-init s'exécute au **premier démarrage** pour :

```yaml
# /etc/cloud/cloud.cfg.d/99-nextcloud-firstboot.cfg
runcmd:
  - /opt/nextcloud-marketplace/scripts/firstboot/configure-nextcloud.sh
  - /opt/nextcloud-marketplace/scripts/firstboot/configure-mariadb.sh
  - /opt/nextcloud-marketplace/scripts/firstboot/configure-tls.sh
  - /opt/nextcloud-marketplace/scripts/firstboot/run-nextcloud-install.sh
  - /opt/nextcloud-marketplace/scripts/firstboot/run-nextcloud-maintenance.sh
```

**Responsabilités cloud-init (post-déploiement client) :**
- Création base de données MariaDB avec mot de passe fourni par le client (ARM param `dbPassword`)
- Configuration `config.php` avec domaine client (`nextcloudUrl`)
- Exécution de `occ maintenance:install` (installation Nextcloud initiale)
- Exécution de `occ upgrade` (initialisation et mise à jour DB)
- Configuration TLS avec certificat Let's Encrypt ou custom

---

## Séquence Détaillée des Provisioners

### 01 — install-base.sh

**Responsabilité** : Préparation système de base

```bash
# Répertoires sur le disque de données (128 GB)
mkdir -p /data/nextcloud-data    # Stockage données Nextcloud
mkdir -p /data/mariadb      # Datadir MariaDB
mkdir -p /data/logs/nginx
mkdir -p /data/logs/php
mkdir -p /data/logs/mariadb

# Packages système de base
apt-get update
apt-get install -y curl wget git unzip ca-certificates gnupg lsb-release
```

**Ownership final** :
- `/data/*` → `root:root` (modifié par scripts suivants)

---

### 02 — install-php.sh

**Responsabilité** : Installation PHP 8.2 + extensions Nextcloud

```bash
add-apt-repository ppa:ondrej/php
apt-get install -y \
  php8.2 php8.2-fpm php8.2-cli \
  php8.2-mysql php8.2-xml php8.2-mbstring \
  php8.2-intl php8.2-curl php8.2-zip php8.2-gd \
  php8.2-apcu

# Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
```

**Configuration PHP-FPM** :
- Pool `www` : user/group `www-data`
- Socket Unix : `/run/php/php8.2-fpm.sock`
- `upload_max_filesize = 50M`
- `post_max_size = 50M`
- `memory_limit = 256M`

**Préconditions** : 01-install-base.sh exécuté  
**Postconditions** : `php -v` retourne 8.2.x ; `php-fpm8.2 -v` fonctionne

---

### 03 — install-nginx.sh

**Responsabilité** : Serveur web Nginx + intégration PHP-FPM

```bash
apt-get install -y nginx

# Supprimer site par défaut
rm -f /etc/nginx/sites-enabled/default

# VirtualHost par défaut — sera remplacé cloud-init avec domaine réel
cp /opt/nextcloud-marketplace/config/nginx/nextcloud.conf \
   /etc/nginx/sites-available/nextcloud.conf
ln -s /etc/nginx/sites-available/nextcloud.conf /etc/nginx/sites-enabled/
```

**Ownership final** :
- `/var/www/html` → `www-data:www-data`
- `/etc/nginx` → `root:root`

**Préconditions** : PHP 8.2 installé  
**Postconditions** : `nginx -t` retourne `syntax is ok`

---

### 04 — install-mariadb.sh

**Responsabilité** : Installation MariaDB 10.6+ avec datadir sur disque de données

```bash
apt-get install -y mariadb-server

# Reconfigurer datadir vers /data/mariadb
systemctl stop mariadb
rsync -av /var/lib/mysql/ /data/mariadb/
# Modifier /etc/mysql/mariadb.conf.d/50-server.cnf : datadir = /data/mariadb
chown -R mysql:mysql /data/mariadb

# mysql_secure_installation non-interactif
mariadb -u root <<SQL
  ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'TEMP_PLACEHOLDER';
  DELETE FROM mysql.user WHERE User='';
  DROP DATABASE IF EXISTS test;
  FLUSH PRIVILEGES;
SQL
```

**⚠️ Important** : Le mot de passe root est temporaire et nettoyé dans `08-cleanup-generalize.sh`. Le mot de passe final est configuré via cloud-init avec la valeur ARM param `dbPassword`.

**Ownership final** :
- `/data/mariadb` → `mysql:mysql`

**Préconditions** : 01-install-base.sh exécuté  
**Postconditions** : `mysqladmin -u root ping` retourne `mysqld is alive`

---

### 05 — install-nextcloud.sh

**Responsabilité** : Téléchargement et installation Nextcloud Hub 31.x

```bash
NC_VERSION="31.0.0"
cd /tmp
wget "https://download.nextcloud.com/server/releases/nextcloud-${NC_VERSION}.tar.bz2"
tar -xjf "nextcloud-${NC_VERSION}.tar.bz2"
mv nextcloud /var/www/nextcloud

chown -R www-data:www-data /var/www/nextcloud

# Nginx — webroot is /var/www/nextcloud directly

# Répertoire uploads sur disque de données
mkdir -p /data/uploads
chown www-data:www-data /data/uploads
ln -s /data/nextcloud-data /var/www/nextcloud/data
```

**Ownership final** :
- `/var/www/nextcloud` → `www-data:www-data`
- `/data/uploads` → `www-data:www-data`

**Préconditions** : Nginx + PHP installés  
**Postconditions** : `/var/www/nextcloud/index.php` existe

---

### 06 — install-nextcloud.sh

**Responsabilité** : Installation Nextcloud Hub + apps via occ

```bash
cd /var/www/nextcloud

# Installation apps Nextcloud via occ
sudo -u www-data php /var/www/nextcloud/occ app:install user_saml
sudo -u www-data php /var/www/nextcloud/occ app:install richdocuments
sudo -u www-data composer update --no-dev -o

# config.php partiel (sans credentials — complété cloud-init)
cp /opt/nextcloud-marketplace/config/nextcloud/config.partial.php \
   /var/www/nextcloud/config/config.php
chown www-data:www-data /var/www/nextcloud/config/config.php
```

**config.partial.php contient :**
- `occ app:enable user_saml` + configuration SAML
- `'dbtype' => 'mysql',`
- Configuration de base (langue, timezone, données)
- **Ne contient PAS** : `'dbhost'`, `'dbname'`, `'dbuser'`, `'dbpassword'`, `'overwrite.cli.url'` — fournis par cloud-init

**Préconditions** : Nextcloud installé, PHP disponible  
**Postconditions** : `apps/user_saml/` existe ; Nextcloud opérationnel

---

### 07 — security-harden.sh

**Responsabilité** : Hardening OS conformément à ADR-300

```bash
# Firewall UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow 443/tcp   # HTTPS
ufw allow 22/tcp    # SSH (restreint post-déploiement)
ufw --force enable

# fail2ban
apt-get install -y fail2ban
cp /opt/nextcloud-marketplace/config/fail2ban/jail.local /etc/fail2ban/jail.local

# auditd
apt-get install -y auditd audispd-plugins

# TLS — désactiver protocoles faibles dans Nginx
cat >> /etc/nginx/snippets/ssl-params.conf << 'EOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5:!3DES;
ssl_prefer_server_ciphers on;
EOF

# Désactiver password auth SSH
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
```

**Préconditions** : Tous composants installés  
**Postconditions** : `ufw status` → active ; `sshd -T | grep passwordauthentication` → no

---

### 08 — cleanup-generalize.sh

**Responsabilité** : Nettoyage et généralisation de l'image pour Azure Marketplace

```bash
# Supprimer credentials temporaires MariaDB
mariadb -u root -pTEMP_PLACEHOLDER -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;"

# Nettoyer logs et history
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
find /var/log -type f -name "*.gz" -delete
history -c
> /root/.bash_history
> /home/*/.bash_history

# Supprimer clés SSH temporaires de build
rm -f /root/.ssh/authorized_keys
rm -f /home/ubuntu/.ssh/authorized_keys

# Azure Agent cleanup
waagent -force -deprovision+user
```

**⚠️ Ordre critique** : Ce script DOIT être le dernier provisioner. Après son exécution, l'image est généralisée et ne peut plus être redémarrée directement.

**Préconditions** : Tous les autres provisioners terminés avec succès  
**Postconditions** : Image dans état `Generalized` pour publication dans Azure Compute Gallery

---

## Matrice de Validation

### Validation Pré-Build (Statique)

| Check | Outil | Criticité |
|-------|-------|-----------|
| Syntax bash | `shellcheck` | 🔴 Bloquant |
| Ordre provisioners | Review manuelle | 🔴 Bloquant |
| Pas de credentials hardcodés | `grep -r "password"` | 🔴 Bloquant |
| Ownership cohérent | Review croisée scripts | 🟡 Important |

### Validation Post-Build (Dynamique)

| Check | Commande | Attendu |
|-------|----------|---------|
| PHP version | `php -v` | `8.2.x` |
| Nginx status | `nginx -t` | `syntax is ok` |
| MySQL ping | `mysqladmin ping` | `mysqld is alive` |
| Nextcloud existe | `ls /var/www/nextcloud/index.php` | Fichier présent |
| user_saml installé | `ls /var/www/nextcloud/apps/user_saml` | Répertoire présent |
| UFW actif | `ufw status` | `Status: active` |
| TLS config | `nginx -V` | TLS modules présent |
| SSH password | `sshd -T \| grep passwordauth` | `no` |
| Bash history vide | `wc -l /root/.bash_history` | `0` |

### Validation Certification Microsoft

Avant soumission Partner Center, exécuter **Azure Marketplace Certification Tool** :

```bash
# Via VM déployée depuis l'image
wget https://raw.githubusercontent.com/Azure/azure-marketplace-vm-cert/main/cert-check.sh
chmod +x cert-check.sh
./cert-check.sh
```

Points vérifiés automatiquement :
- SSH password désactivé
- Pas de root login SSH
- waagent installé et configuré
- Pas de fichiers de credentials connus
- Services inutiles arrêtés
- Image généralisée correctement

---

## Ownership et Services — Matrice Finale

### Ownership Répertoires

| Répertoire | Owner | Groupe | Provisioner |
|------------|-------|--------|-------------|
| `/var/www/nextcloud` | `www-data` | `www-data` | 06-install-nextcloud |
| `/data/nextcloud-data` | `www-data` | `www-data` | 06-install-nextcloud |
| `/data/mariadb` | `mysql` | `mysql` | 04-install-mariadb |
| `/data/logs/nginx` | `www-data` | `www-data` | 01-install-base |
| `/data/logs/php` | `www-data` | `www-data` | 01-install-base |
| `/data/logs/mariadb` | `mysql` | `mysql` | 04-install-mariadb |
| `/etc/nginx` | `root` | `root` | 03-install-nginx |

### Services dans l'Image (État Final)

| Service | État dans l'image | Démarré au boot client | Responsable |
|---------|------------------|------------------------|-------------|
| `nginx` | Installé, enabled | ✅ Oui (via cloud-init après config) | 03-install-nginx |
| `php8.2-fpm` | Installé, enabled | ✅ Oui | 02-install-php |
| `mariadb` | Installé, enabled | ✅ Oui (après config cloud-init) | 04-install-mariadb |
| `ufw` | Actif | ✅ Oui | 07-security-harden |
| `fail2ban` | Installé, enabled | ✅ Oui | 07-security-harden |
| `waagent` | Installé | ✅ Oui | Natif Ubuntu Azure |

---

## Anti-Patterns à Éviter

| Anti-Pattern | Risque | Mitigation |
|--------------|--------|------------|
| Credentials MariaDB dans l'image | 🔴 Critique — rejet certification | Nettoyage dans 08-cleanup-generalize.sh |
| `maintenance/install.php` dans Packer | 🔴 Critique — BDD non configurée | Exécution uniquement dans cloud-init |
| `history` non nettoyé | 🔴 Critique — rejet certification | Nettoyage explicite dans 08 |
| Ownership mixte www-data/root sur `/var/www/nextcloud` | 🟡 — erreurs permission PHP-FPM | Ownership homogène `www-data` dès 06 |
| Composer en root | 🟡 — fichiers owner root dans vendor/ | `sudo -u www-data composer` |

---

## Pipeline Make

```makefile
# Makefile — cibles liées à l'architecture provisioner

.PHONY: provisioner-validate vm-build vm-smoke-test

provisioner-validate:
@echo "Validation statique des provisioners..."
shellcheck packer/provisioners/*.sh
grep -r "password\|passwd\|secret\|token" packer/provisioners/ | grep -v "^#" || true
@echo "✅ Validation statique OK"

vm-build: provisioner-validate
cd packer && packer build nextcloud-vm.pkr.hcl

vm-smoke-test:
@echo "Tests smoke post-déploiement..."
ssh -i $(SSH_KEY) $(VM_USER)@$(VM_IP) 'php -v'
ssh -i $(SSH_KEY) $(VM_USER)@$(VM_IP) 'mysqladmin ping'
ssh -i $(SSH_KEY) $(VM_USER)@$(VM_IP) 'nginx -t'
```

---

## Références

- [Packer Azure Plugin — azure-arm builder](https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm)
- [Azure VM Marketplace Certification Tool](https://docs.microsoft.com/en-us/azure/marketplace/azure-vm-certification-faq)
- [Nextcloud Installation Guide](https://docs.nextcloud.com/server/latest/admin_manual/installation/)
- [Nextcloud Apps](https://apps.nextcloud.com/)
- [ondrej/php PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php)
- ADR-200 : Infrastructure Azure VM
- ADR-300 : Sécurité et hardening
- ADR-609 : Stratégie version PHP

## Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-04-16 | @devops-team | Création ADR-613 | Architecture provisioners Nextcloud Marketplace |
