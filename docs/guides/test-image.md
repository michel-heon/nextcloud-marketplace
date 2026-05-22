# Guide — Test et qualification de l'image VM Nextcloud

Ce guide décrit la procédure complète pour tester une image VM publiée dans l'Azure
Compute Gallery, déboguer les anomalies détectées, et reporter les corrections dans
le processus de construction Packer.

Il s'appuie sur la stratégie de qualification définie dans
[ADR-700](../adr/700-TEST-plan-tests-integration.md) et
[ADR-701](../adr/701-TEST-protocole-qualification-post-image-vm.md),
et sur le cycle de debug décrit dans
[ADR-618](../adr/618-DEVOPS-strategie-debug-post-image-vm.md).

---

## Vue d'ensemble

Le cycle de qualification se déroule en six phases successives :

```
[Image SIG] → [VM de test] → [Smoke L1] → [Services L2] → [E2E L2/IP] → [Cert L3/IP]
                   ↑                                                             |
                   │         [E2E L2/DNS] ← [DNS assign] ←─────────────────────┘
                   └──────────── Backport Packer ←── Correction in-situ ────────┘
```

| Phase | Cible | Durée | Commande |
|-------|-------|-------|----------|
| 1 — Création VM | Instanciation depuis la gallery | ~5 min | `make vm-test-create` |
| 2 — Smoke (Niveau 1) | VM active, SSH, firstboot, services | < 2 min | `make vm-test-smoke` |
| 3 — Services (Niveau 2) | OS, composants, base de données, Nextcloud | ~5 min | `make vm-test-service` |
| 4 — E2E Playwright (Niveau 2) | Navigateur, login, API, redirections — via IP | ~5 min | `make vm-test-e2e` |
| 5 — Certification (Niveau 3) | Conformité Azure Marketplace — via IP | ~10 min | `make vm-test-cert` |
| — | Phases 2 à 5 en séquence | ~25 min | `make vm-test-all` |
| 6 — Assignation DNS | Nom DNS Azure + trusted\_domain Nextcloud | < 1 min | `make vm-test-dns-assign` |
| 6b — E2E via DNS | Re-validation Playwright via FQDN | ~5 min | `make vm-test-dns-e2e` |

> **Pourquoi tester via DNS ?** Les navigateurs et proxies modernes traitent
> différemment les noms d'hôte et les adresses IP : HSTS, cookies SameSite,
> redirections de service discovery (`.well-known/carddav`), et certains comportements
> TLS ne s'appliquent qu'à un FQDN. La phase 6 valide que l'image se comporte
> correctement lorsqu'un utilisateur final accède à Nextcloud par son nom DNS.

---

## Prérequis

### Outils locaux

| Outil | Version minimale | Installation |
|-------|-----------------|--------------|
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | 2.60+ | `brew install azure-cli` / apt |
| [Node.js](https://nodejs.org/) | 18+ | `brew install node` / nvm |
| `make` | 3.81+ | fourni par l'OS |
| `curl` | — | fourni par l'OS |
| `openssl` | — | fourni par l'OS |
| `python3` | 3.8+ | fourni par l'OS |
| Paire de clés SSH | — | `ssh-keygen -t rsa -b 4096` |

### Ressources Azure requises

Les ressources suivantes doivent exister avant de créer une VM de test :

- **Azure Compute Gallery** : `gal_nextcloud_marketplace`  
- **Image definition** : `nextcloud-marketplace`  
- Au moins une version d'image en état `Succeeded` dans la gallery

Vérifier avec :

```bash
make gallery-check
```

### Authentification Azure

```bash
make azure-login
```

---

## Installation de Playwright (une seule fois)

Les tests E2E utilisent [Playwright](https://playwright.dev/) avec le moteur Firefox.
Le dossier `node_modules/` est installé **à la racine du projet**.

```bash
make playwright-install
```

Cette commande exécute `npm install` puis installe Firefox et Chromium avec leurs
dépendances système (`--with-deps`).

---

## Configuration

Les scripts de test appliquent la stratégie ADR-600 en **trois couches** :

| Couche | Fichier | Versionné | Description |
|--------|---------|-----------|-------------|
| 1 | `env/.env` | Non | Config projet (subscription, gallery, IMAGE_VERSION…) |
| 2 | `env/.env.user` | Non | Surcharges personnelles |
| 3 | `image-tests/env/.env.test` | Non | Config spécifique aux tests VM |

Les couches 1 et 2 sont chargées par `env-check` (Makefile standard).
La couche 3 est chargée automatiquement par `load_env()` dans `image-tests/lib/common.sh`.

### Initialiser la configuration de test

```bash
cp -n image-tests/env/.env.test.example image-tests/env/.env.test
# → Éditer image-tests/env/.env.test avec vos valeurs
```

> **Idempotent** : `-n` (no-clobber) ne remplace pas un `.env.test` déjà existant.
> Sur les exécutions suivantes du guide, vos valeurs sont préservées.

> `image-tests/env/.env.test` et `.image-test-state` sont dans `.gitignore`.
> Seul `image-tests/env/.env.test.example` est versionné.

### Variables de test disponibles

| Variable | Défaut | Description |
|----------|--------|-------------|
| `TEST_RG` | `rg-nextcloud-test` | Resource group Azure de la VM de test |
| `TEST_VM_NAME` | `vm-nc-test` | Nom de la VM de test |
| `TEST_VM_SIZE` | `Standard_B2s` | Taille de la VM |
| `TEST_ADMIN_USER` | `azureuser` | Utilisateur SSH de la VM |
| `TEST_SSH_KEY_PATH` | `~/.ssh/id_rsa.pub` | Chemin vers la clé SSH publique |
| `TEST_NC_ADMIN_USER` | `ncadmin` | Administrateur Nextcloud de test |
| `TEST_NC_ADMIN_PASS` | `changeme123!` | Mot de passe admin Nextcloud de test |
| `TEST_NC_DB_PASS` | `dbpassword123!` | Mot de passe PostgreSQL de test |
| `TEST_REDIS_PASS` | `redis123!` | Mot de passe Redis de test |

La version d'image testée est lue depuis `IMAGE_VERSION` dans `env/.env`.

> Les variables **`TEST_VM_IP`** et **`TEST_VM_FQDN`** ne sont **pas** définies dans
> `.env.test` — elles sont écrites dynamiquement dans `.image-test-state` par
> `vm-create.sh` et `vm-dns.sh` respectivement.

| Variable (state) | Source | Description |
|------------------|--------|-------------|
| `TEST_VM_IP` | Écrite par `vm-create.sh` | IP publique de la VM créée |
| `TEST_VM_FQDN` | Écrite par `vm-dns.sh` | FQDN après assignation DNS |
| `IMAGE_VERSION` | Copiée depuis `env/.env` | Version de l'image testée |
| `CREATED_AT` | Horodatage ISO 8601 | Date/heure de création de la VM |

---

## Phase 1 — Créer la VM de test

> **Bootstrap / reprise** : si `.image-test-state` est déjà présent (installation
> précédente), supprimer d'abord la VM existante avant de relancer :
> `make vm-test-delete`

```bash
make vm-test-create
```

Cette commande :

1. Crée le resource group `TEST_RG`
2. Génère un payload cloud-init éphémère avec les credentials de test
3. Instancie la VM depuis l'image gallery `IMAGE_VERSION`
4. Ouvre le port 443 (HTTPS)
5. Attend que SSH soit accessible
6. Attend la fin du service `nextcloud-first-boot` (marqueur `/etc/nextcloud/.first-boot-complete`)
7. Écrit `.image-test-state` à la racine du projet (chmod 600)

À la fin, le résultat attendu est :

```
[OK] VM de test prête
  IP publique : 20.x.x.x
  SSH         : ssh azureuser@20.x.x.x -i ~/.ssh/id_rsa
  HTTPS       : https://20.x.x.x
```

> **Note** : le firstboot peut prendre jusqu'à 10 minutes. La commande attend
> automatiquement sa complétion avant de terminer.

---

## Phase 2 — Smoke Tests (Niveau 1)

```bash
make vm-test-smoke
```

Critères vérifiés :

| Test | Critère de succès |
|------|------------------|
| État VM | `VM running` (Azure PowerState) |
| SSH | Connexion établie en moins de 15 s |
| Firstboot | Marqueur `/etc/nextcloud/.first-boot-complete` présent |
| Services | `nginx`, `php8.3-fpm`, `postgresql`, `redis-server` → `active` |
| HTTPS | `https://<ip>/` répond HTTP 200/301/302 |

Un seul `[FAIL]` arrête la progression. Résoudre les erreurs avant de continuer.

---

## Phase 3 — Vérification des services (Niveau 2)

```bash
make vm-test-service
```

Vérifications approfondies via SSH :

| Section | Critères |
|---------|----------|
| OS | Ubuntu 24.04 LTS |
| Services systemd | `nginx`, `php8.3-fpm`, `postgresql`, `redis-server` actifs |
| PHP | 8.3.x + pool FPM configuré |
| PostgreSQL | 16.x + base `nextcloud` + utilisateur `nextcloud` |
| Redis | 7.x |
| Nextcloud `occ` | `installed=true`, `maintenance=false` |
| Nginx | Config valide (`nginx -t`) + certificat TLS présent |
| Firstboot | Marqueur présent |
| Cron | Timer systemd ou crontab actif |
| Permissions | `config.php` appartient à `www-data:www-data` |

---

## Phase 4 — Tests E2E Playwright (Niveau 2)

```bash
make vm-test-e2e
```

Exécute les specs `image-tests/playwright/` avec Firefox :

| Test | Scénario |
|------|---------|
| T-BROWSER-00 | HTTP redirige vers HTTPS |
| T-BROWSER-01 | Page `/login` accessible, formulaire présent |
| T-BROWSER-01b | `status.php` — `installed=true`, `maintenance=false`, version SemVer |
| T-BROWSER-02 | Connexion admin, navigation vers `/apps/files` |
| T-BROWSER-03 | API OCS `/ocs/v1.php/config` retourne `<ocs>` |
| T-BROWSER-04 | `.well-known/carddav` redirige (301/302/307/308) |
| T-BROWSER-04b | `.well-known/caldav` redirige |

Le rapport HTML est généré dans `.test-reports/playwright/`.

> **En cas d'échec de T-BROWSER-04 / T-BROWSER-04b** : vérifier la configuration
> Nginx pour les endpoints de service discovery. Les redirections
> `.well-known/carddav` et `.well-known/caldav` doivent pointer vers
> `/remote.php/dav` (exemple : `location = /.well-known/carddav { return 301
> /remote.php/dav; }`). Voir [Nextcloud Admin Manual — General
> troubleshooting](https://docs.nextcloud.com/server/latest/admin_manual/issues/general_troubleshooting.html#service-discovery).

---

## Phase 5 — Certification Marketplace (Niveau 3)

```bash
make vm-test-cert
```

Critères de conformité Azure Marketplace :

| Critère | Exigence |
|---------|---------|
| SSH key-only | `PermitRootLogin no/prohibit-password`, `PasswordAuthentication no` |
| Pare-feu | UFW actif, ports 22 et 443 autorisés |
| TLS | TLSv1.2+ (TLSv1.0/1.1 refusés) |
| Credentials | `config.env` supprimé après firstboot, aucun secret en clair |
| waagent | `DeleteRootPassword=y`, `RegenerateSshHostKeyPair=y` |
| Maintenance | Mode maintenance désactivé |
| Fichiers sensibles | `phpinfo.php`, `.env`, `.git/config` non exposés (non-200) |
| Server header | Aucune version de Nginx/PHP divulguée |

> **Étape manuelle complémentaire** : après publication de l'image SIG, exécuter
> l'[Azure Marketplace Certification Tool (AMAT)](https://github.com/Azure/Azure-Certification-Tools)
> sur l'image finale. Voir [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md).

---

## Phase 6 — Assignation DNS et re-validation E2E

Cette phase assigne un nom DNS à l'IP publique de la VM de test, ajoute le FQDN
comme domaine de confiance Nextcloud, puis relance les tests E2E via ce FQDN.

### Pourquoi une phase DNS ?

Les navigateurs et proxies modernes traitent différemment les noms d'hôte et les
adresses IP : HSTS ne s'applique qu'aux noms d'hôte, les cookies `SameSite=Strict`
se comportent différemment sur les IPs, et certains clients CalDAV/CardDAV n'acceptent
que les FQDN. Cette phase valide le comportement réel d'un déploiement en production.

### 6a — Assigner le nom DNS

```bash
make vm-test-dns-assign
```

Cette commande exécute `image-tests/vm-dns.sh` et effectue les opérations suivantes :

1. Lit `TEST_VM_NAME`, `TEST_RG` et `IMAGE_VERSION` depuis `.image-test-state`
2. Construit le label DNS : `nc-test-v{version}` (ex. `0.1.3` → `nc-test-v0-1-3`)
3. Récupère le nom de la ressource IP publique Azure via `az vm list-ip-addresses`
4. Assigne le label via `az network public-ip update --dns-name`
5. Récupère le FQDN résultant : `nc-test-v0-1-3.canadacentral.cloudapp.azure.com`
6. Ajoute le FQDN comme `trusted_domains[1]` Nextcloud via `occ config:system:set`
7. Écrit `TEST_VM_FQDN=<fqdn>` dans `.image-test-state`

À la fin, le résultat attendu est :

```
[OK] Nom DNS assigné avec succès

  FQDN  : nc-test-v0-1-3.canadacentral.cloudapp.azure.com
  HTTPS : https://nc-test-v0-1-3.canadacentral.cloudapp.azure.com

  Prochaine étape : make vm-test-dns-e2e
```

> **Format du label DNS** : `nc-test-v{version}-{region}` avec les `.` remplacés
> par des `-`. Le label est unique par version et région, ce qui évite les
> conflits si plusieurs VMs de test coexistent dans des régions différentes.

> **Propagation DNS** : le FQDN Azure (`*.cloudapp.azure.com`) est résolu
> immédiatement sans délai de propagation DNS externe. Le test peut être lancé
> dès que la commande retourne.

### 6b — Re-lancer les tests E2E via DNS

```bash
make vm-test-dns-e2e
```

Exécute les mêmes specs Playwright qu'en Phase 4, mais en utilisant le FQDN
comme cible. Après `vm-test-dns-assign`, le fichier `.image-test-state` contient
`TEST_VM_FQDN` ; `playwright.config.js` le détecte automatiquement et utilise
le FQDN comme `baseURL`.

| Test | Comportement spécifique via FQDN |
|------|----------------------------------|
| T-BROWSER-00 | HTTP redirige vers `https://<fqdn>` (vérifie que l'hôte de la redirection est correct) |
| T-BROWSER-01 | Page de login accessible via le nom DNS |
| T-BROWSER-01b | `status.php` — cohérence de l'installation |
| T-BROWSER-02 | Connexion admin via FQDN |
| T-BROWSER-03 | API OCS via FQDN |
| T-BROWSER-04 | `.well-known/carddav` redirige via FQDN |
| T-BROWSER-04b | `.well-known/caldav` redirige via FQDN |
| M-SEC-01 | HTTPS accessible via FQDN (même cert auto-signé, `ignoreHTTPSErrors: true`) |
| M-SEC-02 | Headers de sécurité présents (`Strict-Transport-Security`, `X-Frame-Options`) |
| M-SEC-03 | `Server:` header sans version Nginx/PHP |

> **trusted_domains requis** : si la phase 6a a été correctement exécutée,
> Nextcloud accepte les requêtes vers le FQDN. Sans cette configuration,
> Nextcloud retourne `Access through untrusted domain` (HTTP 400).
> Vérifier avec : `make vm-test-ssh` puis :
> `sudo -u www-data php /var/www/nextcloud/occ config:system:get trusted_domains`

---

## Connexion SSH à la VM de test

Pour ouvrir une session interactive :

```bash
make vm-test-ssh
```

Pour exécuter une commande distante :

```bash
bash image-tests/vm-ssh.sh journalctl -u nextcloud-first-boot --no-pager
bash image-tests/vm-ssh.sh sudo nginx -t
bash image-tests/vm-ssh.sh sudo -u www-data php /var/www/nextcloud/occ status
```

---

## Cycle de correction (ADR-618)

Lorsqu'un test échoue, appliquer le cycle en trois étapes :

### Étape 1 — Observer (SSH / journaux)

```bash
make vm-test-ssh

# Journaux firstboot
sudo journalctl -u nextcloud-first-boot.service --no-pager -n 100

# Journaux Nginx
sudo tail -50 /var/log/nginx/error.log

# Journaux PHP-FPM
sudo tail -50 /var/log/php8.3-fpm.log

# Journal applicatif Nextcloud (loglevel 0-4, défaut : data/nextcloud.log)
sudo tail -50 /var/www/nextcloud/data/nextcloud.log

# Statut Nextcloud
sudo -u www-data php /var/www/nextcloud/occ status
# → installed: true, maintenance: false, version: 33.x.x

# Vérification des dépendances (DB, modules PHP, intégrité)
sudo -u www-data php /var/www/nextcloud/occ check

# Mode maintenance (doit être désactivé en opération normale)
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode

# Diagnostic détaillé d'une commande occ (-v / -vv / -vvv)
NC_loglevel=0 sudo -E -u www-data php /var/www/nextcloud/occ status -vvv

# Variables d'environnement firstboot
sudo cat /etc/nextcloud/config.env       # présent avant firstboot, supprimé après
```

### Étape 2 — Corriger in-situ sur la VM

Appliquer la correction directement sur la VM de test :

```bash
# Exemple : corriger un script de configuration
sudo nano /usr/local/bin/nc-first-boot.sh

# Relancer le firstboot manuellement
sudo rm -f /etc/nextcloud/.first-boot-complete
sudo systemctl start nextcloud-first-boot.service
sudo journalctl -fu nextcloud-first-boot.service
```

Valider que le test correspondant passe maintenant :

```bash
make vm-test-smoke
make vm-test-service
```

### Étape 3 — Reporter la correction dans Packer

Une fois la correction validée in-situ, reporter dans le provisioner source :

| Fichier modifié sur la VM | Provisioner Packer correspondant |
|---------------------------|----------------------------------|
| `/usr/local/bin/nc-first-boot.sh` | `packer/nextcloud/scripts/12-configure-services.sh` |
| `/etc/nginx/sites-available/nextcloud` | `packer/nextcloud/scripts/06-configure-nginx.sh` |
| `/etc/php/8.3/fpm/pool.d/nextcloud.conf` | `packer/nextcloud/scripts/07-configure-php.sh` |
| `/etc/postgresql/...` | `packer/nextcloud/scripts/08-configure-postgresql.sh` |
| `/etc/redis/redis.conf` | `packer/nextcloud/scripts/09-configure-redis.sh` |
| `/etc/waagent.conf` | `packer/nextcloud/scripts/99-sysprep.sh` |

Après correction dans les provisioners :

```bash
# 1. Supprimer la VM de test
make vm-test-delete

# 2. Reconstruire l'image
make image-build

# 3. Créer une nouvelle VM de test et retester
make vm-test-create
make vm-test-all
```

---

## Nettoyage

```bash
make vm-test-delete
```

Supprime le resource group `TEST_RG` (VM, disque, NIC, IP publique) et le fichier
`.image-test-state`. L'opération de suppression Azure est lancée en arrière-plan.

> **Important** : la VM de test génère des coûts Azure. Toujours supprimer après
> utilisation.

---

## Structure des artefacts de test

```
image-tests/
├── env/
│   ├── .env.test.example    # Modèle versionné (ADR-600) — à copier en .env.test
│   └── .env.test            # Config locale non versionnée (gitignored)
├── lib/
│   └── common.sh            # Bibliothèque partagée (ADR-604)
│                            #   couleurs, logging, load_env(), load_state(), ssh_run()
├── vm-create.sh          # Phase 1 — Instanciation de la VM de test
├── vm-delete.sh          # Nettoyage — Suppression de la VM et du resource group
├── vm-ssh.sh             # Connexion SSH (interactive ou commande)
├── vm-dns.sh             # Phase 6 — Assignation DNS + trusted_domain Nextcloud
├── smoke-test.sh         # Phase 2 — Niveau 1 smoke tests
├── service-check.sh      # Phase 3 — Niveau 2 vérification des services
├── marketplace-cert.sh   # Phase 5 — Niveau 3 conformité Azure Marketplace
└── playwright/
    ├── playwright.config.js     # Configuration Playwright (ESM)
    │                            #   Lit TEST_VM_FQDN dans .image-test-state si disponible,
    │                            #   sinon TEST_VM_IP. Export: vmIp, vmFqdn, adminUser, adminPass
    ├── nextcloud.spec.js        # Phase 4/6b — Tests E2E Nextcloud (Niveau 2)
    └── marketplace.spec.js      # Phase 4/6b — Tests de sécurité Marketplace (Niveau 3)

.image-test-state         # État de la VM active (chmod 600, gitignored)
                          #   TEST_VM_NAME, TEST_RG, TEST_VM_IP, TEST_ADMIN_USER,
                          #   TEST_SSH_KEY_PATH, TEST_NC_ADMIN_USER, TEST_NC_ADMIN_PASS,
                          #   IMAGE_VERSION, CREATED_AT
                          #   TEST_VM_FQDN  ← ajouté par vm-dns.sh (Phase 6)
.test-reports/
└── playwright/           # Rapport HTML Playwright (gitignored)
playwright-report/        # Rapport alternatif Playwright (gitignored)
test-results/             # Traces Playwright (gitignored)
package.json              # Dépendances Node.js (Playwright)
node_modules/             # Installé à la racine (gitignored)
```

---

## Références

### Documentation interne

- [ADR-618](../adr/618-DEVOPS-strategie-debug-post-image-vm.md) — Stratégie de debug post-image VM
- [ADR-700](../adr/700-TEST-plan-tests-integration.md) — Plan de tests d'intégration
- [ADR-701](../adr/701-TEST-protocole-qualification-post-image-vm.md) — Protocole de qualification post-image
- [ADR-300](../adr/300-SEC-securite-hardening-vm-certification.md) — Sécurité et hardening
- [ADR-800](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md) — Publication Azure Marketplace
- [ADR-802](../adr/802-BIZ-sources-officielles-azure-marketplace.md) — Sources officielles Azure Marketplace (référentiel anti-hallucination)
- [Guide de construction](build-image.md) — Construction de l'image avec Packer

### Références web

#### Configuration et gestion des secrets (ADR-600)

| Pratique | Source | URL |
|----------|--------|-----|
| Pattern `.env` / variables d'environnement | The Twelve-Factor App (Heroku) | <https://12factor.net/config> |
| Ne jamais committer de secrets | OWASP Secrets Management Cheat Sheet | <https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html> |

#### Scripts Bash et modularisation (ADR-601, ADR-604)

| Pratique | Source | URL |
|----------|--------|-----|
| `set -euo pipefail` — mode strict Bash | GNU Bash Reference Manual | <https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin> |
| `# shellcheck source=` — analyse statique | ShellCheck (documentation officielle) | <https://www.shellcheck.net/> |
| Principe DRY — bibliothèques partagées | The Pragmatic Programmer (résumé WIKI) | <https://en.wikipedia.org/wiki/Don%27t_repeat_yourself> |

#### Azure Compute Gallery et provisioning VM

| Pratique | Source | URL |
|----------|--------|-----|
| Stockage et distribution d'images via SIG | Microsoft Learn — Azure Compute Gallery | <https://learn.microsoft.com/en-us/azure/virtual-machines/azure-compute-gallery> |
| Automatisation cloud-init (déploiement VM) | cloud-init documentation | <https://cloudinit.readthedocs.io/en/latest/> |
| Automatisation de build image avec Packer | Mastering the Marketplace — Packer overview | <https://microsoft.github.io/Mastering-the-Marketplace/vm/#vm-automation-with-packer-overview> |

#### Tests E2E Playwright

| Pratique | Source | URL |
|----------|--------|-----|
| Configuration Playwright (ESM, `ignoreHTTPSErrors`) | Playwright — Getting Started | <https://playwright.dev/docs/intro> |
| Tests de navigation et login | Playwright — Writing Tests | <https://playwright.dev/docs/writing-tests> |
| Firefox headless pour tests TLS auto-signé | Playwright — Browser configuration | <https://playwright.dev/docs/browsers> |

#### DNS Azure et domaines Nextcloud (Phase 6)

| Pratique | Source | URL |
|----------|--------|-----|
| Assigner un label DNS à une IP publique Azure | Microsoft Learn — `az network public-ip update` | <https://learn.microsoft.com/en-us/cli/azure/network/public-ip#az-network-public-ip-update> |
| Format FQDN Azure (`*.cloudapp.azure.com`) | Microsoft Learn — DNS pour IP publiques Azure | <https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/public-ip-addresses#dns-hostname-resolution> |
| `occ config:system:set trusted_domains` | Nextcloud Admin Manual — Configuration system | <https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/config_sample_php_parameters.html#trusted-domains> |
| Erreur "Access through untrusted domain" | Nextcloud Admin Manual — General troubleshooting | <https://docs.nextcloud.com/server/latest/admin_manual/issues/general_troubleshooting.html#access-through-untrusted-domain> |
| HSTS — comportement différent IP vs FQDN | MDN Web Docs — HTTP Strict Transport Security | <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Strict-Transport-Security> |

#### Certification Azure Marketplace (ADR-800)

| Pratique | Source | URL |
|----------|--------|-----|
| Politiques de certification (sections 100, 200, 200.5) | Microsoft Legal — Marketplace Certification Policies | <https://learn.microsoft.com/fr-fr/legal/marketplace/certification-policies> |
| FAQ certification image VM | Microsoft Learn — Azure VM Certification FAQ | <https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-certification-faq> |
| Processus de certification bout-en-bout | Mastering the Marketplace — Certification process | <https://microsoft.github.io/Mastering-the-Marketplace/vm/#the-virtual-machine-offer-certification-process> |
| AMAT — Azure Marketplace Assessment Tool | Mastering the Marketplace — VM test tools | <https://microsoft.github.io/Mastering-the-Marketplace/vm/#virtual-machine-test-tools-for-marketplace-demo> |

#### Sécurité SSH, TLS et hardening (ADR-300)

| Pratique | Source | URL |
|----------|--------|-----|
| `PermitRootLogin no`, `PasswordAuthentication no` | Mastering the Marketplace — Securing your VM | <https://microsoft.github.io/Mastering-the-Marketplace/vm/#securing-your-virtual-machine> |
| `waagent` — `DeleteRootPassword=y`, `RegenerateSshHostKeyPair=y` | Azure Linux Agent (WALinuxAgent) — GitHub | <https://github.com/Azure/WALinuxAgent> |
| Désactivation TLS 1.0 / 1.1 (TLS 1.2+ obligatoire) | RFC 8996 — Deprecating TLS 1.0 and 1.1 (IETF) | <https://datatracker.ietf.org/doc/rfc8996/> |
| Server headers — ne pas divulguer les versions | OWASP HTTP Security Response Headers | <https://owasp.org/www-project-secure-headers/> |
| Pare-feu UFW — ports minimaux exposés | OWASP Network Security Cheat Sheet | <https://cheatsheetseries.owasp.org/cheatsheets/Network_Segmentation_Cheat_Sheet.html> |

#### Nextcloud

| Pratique | Source | URL |
|----------|--------|-----|
| `occ status`, `occ check` — vérification de l'installation | Nextcloud Admin Manual — Using the occ command | <https://docs.nextcloud.com/server/latest/admin_manual/occ_command.html> |
| Logs Nextcloud — emplacement et niveaux (`loglevel`, `logfile`) | Nextcloud Admin Manual — Logging | <https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/logging_configuration.html> |
| Mode maintenance — activer/désactiver avant publication | Nextcloud Admin Manual — Maintenance | <https://docs.nextcloud.com/server/latest/admin_manual/maintenance/index.html> |
| Background jobs — timer systemd ou crontab (`occ background:cron`) | Nextcloud Admin Manual — Background jobs | <https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/background_jobs_configuration.html> |
| Cache mémoire Redis — `memcache.distributed`, `memcache.locking` | Nextcloud Admin Manual — Memory caching | <https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/caching_configuration.html> |
| `.well-known/caldav`, `.well-known/carddav` — service discovery | Nextcloud Admin Manual — General troubleshooting | <https://docs.nextcloud.com/server/latest/admin_manual/issues/general_troubleshooting.html> |
| Avertissements admin — HSTS, CalDAV/CardDAV, intégrité du code | Nextcloud Admin Manual — Security setup warnings | <https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/security_setup_warnings.html> |
