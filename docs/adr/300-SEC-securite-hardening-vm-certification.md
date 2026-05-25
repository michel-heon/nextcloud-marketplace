---
adr: 300
title: "Sécurité VM — Hardening OS Ubuntu pour Certification Azure Marketplace"
status: "accepted"
date: 2026-05-25
superseded_by: null
replaces: null
related_adrs: [200, 800]
related_issues: [4, 29]

classification:
  lifecycle: "accepted"
  domain: "security"
  impact: "critical"
  quality:
    - "security"
    - "compliance"
    - "reliability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "tls"
    - "nsg"
    - "nextcloud"
    - "nginx"
    - "mariadb"

tags: ["security", "hardening", "tls", "ssh", "ufw", "certification", "azure-marketplace", "ubuntu"]
stakeholders: ["@devops-team", "@architecture-team"]
effort: "medium"
---

# ADR-300 : Sécurité VM — Hardening OS pour Certification Azure Marketplace

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-02-22 |
| **Impact** | 🔴 Critique (tests de certification automatisés Microsoft) |
| **Risque technique** | 🔴 Élevé (rejet certification si non conforme) |
| **Portée** | Tactique — provisioner `security-harden.sh` |

---

## 🎯 Contexte

Microsoft exécute le **AMAT (Azure Marketplace Certification Tool)** sur chaque image soumise. Les échecs les plus fréquents concernent la sécurité OS. Ce document centralise les 15 contrôles critiques et les décisions prises pour y répondre.

**Source** : [Azure VM certification test cases](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-certification-faq)

---

## 💡 Décisions de Sécurité

### 1. SSH — Authentification par Clé Uniquement

```bash
# /etc/ssh/sshd_config.d/99-marketplace-hardening.conf
PasswordAuthentication no
PermitRootLogin no
ChallengeResponseAuthentication no
ClientAliveInterval 180
ClientAliveCountMax 3
MaxAuthTries 3
AllowTcpForwarding no
X11Forwarding no
```

**Test Microsoft** : vérifie que `PasswordAuthentication` est `no`.

### 2. TLS — Nginx

Configuré dans `packer/provisioners/configure-tls.sh` (ADR-617) :
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers   ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...;
```

**Test Microsoft** : vérifie le rejet de TLS 1.1 et inférieur.

### 3. Firewall UFW

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 443/tcp    # HTTPS — Nextcloud
ufw allow 80/tcp     # HTTP → redirect HTTPS
ufw allow 22/tcp     # SSH (restreint par NSG côté Azure — voir ADR-200)
ufw deny  3306/tcp   # MariaDB — jamais exposé publiquement
ufw deny  6379/tcp   # Redis — jamais exposé publiquement
ufw deny  9000/tcp   # PHP-FPM — jamais exposé publiquement
ufw --force enable
```

### 4. Isolation Réseau MariaDB, Redis et PHP-FPM

Les services MariaDB, Redis et PHP-FPM n'écoutent que sur loopback. Configuré dans les fichiers de configuration :

```ini
# /etc/mysql/mariadb.conf.d/50-server.cnf
[mysqld]
bind-address = 127.0.0.1
```

```ini
# /etc/redis/redis.conf
bind 127.0.0.1 ::1
protected-mode yes
```

### 5. Pas de Credentials par Défaut

- Aucun mot de passe hardcodé dans l'image
- Le mot de passe MariaDB est injecté par `cloud-init` depuis les paramètres ARM (`dbPassword`)
- Le mot de passe root est désactivé

```bash
# Dans packer provisioner : désactiver root password
sudo passwd -l root
```

### 6. Permissions Fichiers Sensibles

```bash
chmod 600 /etc/nginx/ssl/server.key
chmod 644 /etc/nginx/ssl/server.crt
chown root:root /etc/nginx/ssl/server.key
chmod 750 /var/www/nextcloud
chown -R www-data:www-data /var/www/nextcloud/ /data/nextcloud-data/
```

### 7. Nettoyage Avant Généralisation

Exécuté en **dernier provisioner Packer** (voir ADR-700) :

```bash
# packer/provisioners/generalize.sh
# Vider l'historique shell
history -c && cat /dev/null > ~/.bash_history

# Supprimer logs et fichiers temporaires
find /tmp -type f -delete
find /var/log -type f -exec truncate -s 0 {} \;

# Supprimer les SSH host keys (régénérées au prochain boot)
rm -f /etc/ssh/ssh_host_*

# Supprimer les clés autorisées du build
rm -f /home/*/.ssh/authorized_keys

# Généralisation Azure — TOUJOURS DERNIER
sudo waagent -deprovision+user -force
```

**Test Microsoft** : vérifie que `~/.bash_history` est vide après généralisation.

### 8. Mise à Jour OS Avant Généralisation

```bash
apt-get update && apt-get upgrade -y && apt-get autoremove -y
```

---

## ✅ Checklist Tests Certification Microsoft (politique 200)

> Mise à jour 2026-05-25 : ajout des contrôles manquants découverts lors de l'audit
> de couverture vs politique officielle sections 200.3.3, 200.4 et 200.5.

### Contrôles OS et Agent (200.3.3)

| # | Test | Décision | Provisioner |
|---|------|----------|-------------|
| 1 | `waagent` installé et démarré | ✅ | `waagent-cloud-init.sh` |
| 2 | SSH root désactivé | ✅ | `security-harden.sh` |
| 3 | `PasswordAuthentication no` | ✅ | `security-harden.sh` |
| 4 | Pas de compte user avec mot de passe vide | ✅ | `generalize.sh` |
| 5 | `bash_history` vide après déprovision | ✅ | `generalize.sh` |
| 6 | `/tmp` vide après généralisation | ✅ | `generalize.sh` |
| 7 | SSH host keys absentes | ✅ | `generalize.sh` |
| 8 | TLS 1.1 rejeté | ✅ | `configure-nginx.sh` |
| 9 | TLS 1.2 accepté | ✅ | `configure-nginx.sh` |
| 10 | Ports 3306/6379 non exposés publiquement | ✅ | `security-harden.sh` + NSG |
| 11 | OS disk < 2 048 GB | ✅ | Packer config |
| 12 | 2 048 premiers secteurs libres | ✅ | Image Ubuntu endorsée |
| 13 | Mise à jour OS récente | ✅ | `security-harden.sh` |
| 14 | `cloud-init` opérationnel | ✅ | `waagent-cloud-init.sh` |
| 15 | Extensions Azure acceptées (`allowExtensionOperations`) | ✅ | `waagent-cloud-init.sh` |

### Contrôles Plateforme Linux Azure (200.3.3 / 200.4)

| # | Test | Décision | Provisioner |
|---|------|----------|-------------|
| 16 | Architecture OS 64-bit (x86_64 ou aarch64) | ✅ | Image Ubuntu endorsée |
| 17 | Driver `hv_netvsc` chargé ou compilé (Hyper-V réseau) | ✅ | Kernel Ubuntu HWE |
| 18 | Pas de partition swap active sur l'OS disk | ✅ | Packer — pas de swap dans cloud-init |
| 19 | `console=ttyS0` dans `GRUB_CMDLINE_LINUX` (serial console Azure) | ✅ | `install-base.sh` ou grub config |
| 20 | Azure Linux Agent ≥ 2.2.10 | ✅ | `waagent-cloud-init.sh` |

### Contrôles Propreté Image (200.5)

| # | Test | Décision | Provisioner |
|---|------|----------|-------------|
| 21 | Clés SSH de build (`authorized_keys`) absentes dans `/root` et `/home` | ✅ | `generalize.sh` |
| 22 | OpenSSL ≥ 1.0 installé | ✅ | `install-base.sh` |
| 23 | Aucun antivirus/EDR (Microsoft Defender/MDATP) pré-installé | ✅ | `generalize.sh` — non installé |

---

## 📁 Structure Provisioners Packer

```
packer/provisioners/
  01-install-base.sh          ← curl, wget, ufw, outils système
  02-install-php.sh           ← PHP 8.2-fpm + extensions Nextcloud
  03-install-nginx.sh         ← Nginx + config VirtualHost
  04-install-mariadb.sh       ← MariaDB 10.6+ + base de données nextcloud
  05-install-redis.sh         ← Redis (cache sessions et fichiers)
  06-install-nextcloud.sh     ← Nextcloud Hub + occ install + configuration
  07-configure-tls.sh         ← certificat TLS auto-signé + nginx HTTPS
  08-security-harden.sh       ← SSH config + UFW + permissions + apt upgrade
  09-generalize.sh            ← cleanup + waagent -deprovision+user  ← TOUJOURS DERNIER
```

---

## 📎 Références

- ADR-200 : Infrastructure Azure (NSG complémentaire à UFW)
- ADR-617 : Packer — outil de construction d'images VM
- ADR-800 : Publication Azure Marketplace (15 tests certification)
- Issue #29 : Implémentation hardening OS
