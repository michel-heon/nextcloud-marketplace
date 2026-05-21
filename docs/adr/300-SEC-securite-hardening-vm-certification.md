---
adr: 300
title: "Sécurité VM — Hardening OS Ubuntu pour Certification Azure Marketplace"
status: "accepted"
date: 2026-02-22
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
    - "mediawiki"
    - "apache"

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

Déjà implémenté dans `docker/nginx/server.conf` (ADR-606) :
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers   ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...;
```

**Test Microsoft** : vérifie le rejet de TLS 1.1 et inférieur.

### 3. Firewall UFW

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 443/tcp    # HTTPS — MediaWiki
ufw allow 80/tcp     # HTTP → redirect HTTPS
ufw allow 22/tcp     # SSH (restreint par NSG côté Azure — voir ADR-200)
ufw deny  3306/tcp   # MySQL — jamais exposé publiquement
ufw deny  9000/tcp   # PHP-FPM — jamais exposé publiquement
ufw --force enable
```

### 4. Isolation Réseau MySQL et PHP-FPM

Les services MySQL et PHP-FPM n'écoutent que sur loopback. Configuré dans les unit files systemd :

```ini
# /etc/systemd/system/mysql.service (bind-address)
[Service]
bind-address = 127.0.0.1  # dans /etc/mysql/mysql.conf.d/mysqld.cnf
```

```ini
# /etc/systemd/system/php8.2-fpm.service
[Service]
Environment=CATALINA_OPTS=-Djava.net.preferIPv4Stack=true
# server.xml : Connector address="127.0.0.1"
```

### 5. Pas de Credentials par Défaut

- Aucun mot de passe hardcodé dans l'image
- Le mot de passe MySQL est injecté par `cloud-init` depuis les paramètres ARM (`mysqlPassword`)
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
chmod 750 /data/server/home
chown -R www-data:www-data /opt/mediawiki/ /data/uploads/
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

## ✅ Checklist 15 Tests Certification Microsoft

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
| 10 | Port 8983 non exposé publiquement | ✅ | `security-harden.sh` + NSG |
| 11 | OS disk < 2 048 GB | ✅ | Packer config |
| 12 | 2 048 premiers secteurs libres | ✅ | Image Ubuntu endorsée |
| 13 | Mise à jour OS récente | ✅ | `security-harden.sh` |
| 14 | `cloud-init` opérationnel | ✅ | `waagent-cloud-init.sh` |
| 15 | Extensions Azure acceptées (`allowExtensionOperations`) | ✅ | `waagent-cloud-init.sh` |

---

## 📁 Structure Provisioners Packer

```
packer/provisioners/
  01-install-base.sh          ← curl, wget, ufw, outils système
  02-install-php.sh           ← PHP 8.2-fpm + extensions MediaWiki
  03-install-apache.sh        ← Apache 2.4 + mod_proxy_fcgi
  04-install-mysql.sh         ← MySQL 8.x + base de données wiki
  05-install-mediawiki.sh     ← MediaWiki 1.43.x + configuration
  06-security-harden.sh       ← SSH config + UFW + permissions + apt upgrade
  06-install-smw.sh           ← Semantic MediaWiki 6.0.1 + extensions SSO
  08-generalize.sh            ← cleanup + waagent -deprovision+user  ← TOUJOURS DERNIER
```

---

## 📎 Références

- ADR-100 : Architecture Docker → VM (Dockerfiles source de vérité)
- ADR-200 : Infrastructure Azure (NSG complémentaire à UFW)
- ADR-700 : Stratégie waagent + généralisation (tests locaux avant Azure)
- ADR-800 : Publication Azure Marketplace (15 tests certification)
- Issue #29 : Implémentation hardening OS
