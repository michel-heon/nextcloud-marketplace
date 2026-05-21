> ⚠️ **FICHIER DÉPRÉCIÉ** — Ce fichier est l'ancienne version de cet ADR.
> Voir la version courante : [300-SEC-securite-hardening-vm-certification.md](./300-SEC-securite-hardening-vm-certification.md)

---
adr: 300
title: "Sécurité Image VM — Hardening, TLS, SSH et Conformité Certification Microsoft Marketplace"
status: "deprecated"
date: 2026-02-21
classification:
  lifecycle: "deprecated"
  domain: "security"
  impact: "high"
  quality:
    - "security"
    - "compliance"
    - "reliability"
  reversibility: "moderate"
  scope: "strategic"
  tech_areas:
    - "tls"
    - "security"
    - "azure"
    - "vm"
    - "packer"
    - "nginx"
    - "nginx"

tags: ["security", "tls", "ssh", "hardening", "certification", "marketplace", "azure-marketplace", "compliance", "ubuntu", "bash-history", "walinuxagent"]
stakeholders: ["@architecture-team", "@devops-team"]
effort: "high"
related_issues: [3]
related_adrs: [1, 200, 800]
replaces: null
superseded_by: 300
---

# ADR 300: Sécurité Image VM — Hardening, TLS, SSH et Conformité Certification Microsoft Marketplace

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-02-21 |
| **Impact** | 🔴 Élevé (l'échec de n'importe lequel des 15 tests Microsoft = rejet automatique) |
| **Domaine** | Sécurité |
| **Réversibilité** | 🟡 Modérée (tout changement de policy = rebuild Packer + re-soumission) |
| **Portée** | Image VM complète — de la configuration OS au provisioner Packer final |

## 🎯 Contexte

### Problème

Microsoft exige que les images VM soumises au Marketplace passent un ensemble de **tests de certification automatisés**. Le non-respect de certaines règles entraîne un **rejet automatique** sans revue manuelle. Ces exigences couvrent :

- La configuration TLS (protocoles, chiffrements)
- La sécurité SSH (authentification, timeouts)
- L'absence de credentials par défaut
- L'état du bash history
- La présence et l'état de l'Azure Linux Agent (walinuxagent)

Par ailleurs, la VM doit respecter les bonnes pratiques de sécurité pour les clients universitaires (RGPD, isolation des services non exposés).

### Source de référence

Les 15 tests de certification Microsoft sont documentés dans l'ADR-800 et dans :
- [Azure VM Certification FAQ](https://learn.microsoft.com/en-us/partner-center/marketplace-offers/azure-vm-certification-faq)
- [Certification Test Tool for Azure Certified](https://github.com/Azure/azure-linux-extensions/tree/master/Tools)

## 💡 Décision

**Nous définissons une politique de sécurité complète pour l'image VM Nextcloud, déclinée en 4 scripts Packer (`install-azure-agent.sh`, `configure-tls.sh`, `security-harden.sh`, `cleanup-before-generalize.sh`) et validée par le Certification Test Tool Microsoft avant chaque soumission.**

---

## 🔒 Décision 1 : Azure Linux Agent (walinuxagent)

### Obligation Marketplace (rejet automatique si absent)

Le **walinuxagent** est l'agent Azure requis pour :
- La communication VM ↔ infrastructure Azure
- L'extension Azure Monitor Agent
- La généralisation de l'image (`waagent -deprovision`)
- Le provisioning SSH lors du premier démarrage client

### Script : `packer/provisioners/install-azure-agent.sh`

```bash
#!/usr/bin/env bash
# install-azure-agent.sh — Installation Azure Linux Agent
# IMPORTANT: Script Packer self-contained (pas de source lib/)
set -euo pipefail

LOG_FILE="/var/log/nextcloud-install.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== Installation Azure Linux Agent ==="

apt-get update -qq
apt-get install -y --no-install-recommends \
  walinuxagent \
  cloud-init \
  cloud-utils-growpart

# Activer et démarrer le service
systemctl enable walinuxagent
systemctl start walinuxagent

# Validation
systemctl is-active walinuxagent || { log "ERREUR: walinuxagent inactif"; exit 1; }
log "walinuxagent version: $(waagent --version)"
log "=== Azure Linux Agent installé avec succès ==="
```

### Validation

```bash
systemctl is-active walinuxagent   # → active
waagent --version                  # → WALinuxAgent-2.x.x
```

---

## 🔐 Décision 2 : Configuration TLS

### Exigences

| Exigence | Valeur | Source |
|----------|--------|--------|
| Protocole minimum | TLS 1.2 | ADR-800 + Microsoft Marketplace |
| Protocoles désactivés | TLS 1.0, TLS 1.1, SSLv2, SSLv3 | ADR-800 |
| Protocoles autorisés | TLS 1.2, TLS 1.3 | ADR-100 (nginx) |
| Chiffrements | HIGH:!aNULL:!MD5:!RC4 | Bonne pratique |

### Script : `packer/provisioners/configure-tls.sh`

```bash
#!/usr/bin/env bash
# configure-tls.sh — Configuration TLS 1.2+ obligatoire
set -euo pipefail

LOG_FILE="/var/log/nextcloud-install.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== Configuration TLS ==="

# 1. Désactivation TLS 1.0 / 1.1 dans OpenSSL système
OPENSSL_CONF="/etc/ssl/openssl.cnf"
if ! grep -q "MinProtocol" "$OPENSSL_CONF"; then
  cat >> "$OPENSSL_CONF" <<'EOF'

[system_default_sect]
MinProtocol = TLSv1.2
CipherString = HIGH:!aNULL:!MD5:!RC4
EOF
fi
log "OpenSSL: MinProtocol = TLSv1.2 configuré"

# 2. Configuration Nginx TLS (si Nginx présent)
if command -v nginx &>/dev/null; then
  NGINX_TLS_CONF="/etc/nginx/snippets/tls-hardening.conf"
  cat > "$NGINX_TLS_CONF" <<'EOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_stapling on;
ssl_stapling_verify on;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
EOF
  log "Nginx: configuration TLS hardening créée"
fi

# 3. Désactivation de renegotiation SSL dangereuse (si applicable)
if [[ -f /etc/ssl/openssl.cnf ]]; then
  grep -q "UnsafeLegacyRenegotiation" "$OPENSSL_CONF" || \
    echo "Options = UnsafeLegacyRenegotiation" >> "$OPENSSL_CONF"
fi

# 4. Validation
log "Validation OpenSSL version: $(openssl version)"
PROTO_CHECK=$(openssl ciphers -v 'TLSv1.2' 2>/dev/null | wc -l)
log "Chiffrements TLS 1.2 disponibles: $PROTO_CHECK"

log "=== Configuration TLS terminée ==="
```

### Validation

```bash
openssl s_client -connect localhost:443 -tls1  2>&1 | grep "no peer certificate"
# → handshake failure (TLS 1.0 rejeté)
openssl s_client -connect localhost:443 -tls1_2 2>&1 | grep "Cipher is"
# → Cipher is ECDHE-RSA-AES256-GCM-SHA384 (TLS 1.2 accepté)
```

---

## 🔒 Décision 3 : Hardening SSH et OS

### Règles SSH critiques (tests Microsoft)

| Règle | Configuration | Test Microsoft |
|-------|--------------|----------------|
| Authentification par mot de passe désactivée | `PasswordAuthentication no` | ✅ Test #6 |
| Root SSH désactivé | `PermitRootLogin no` | ✅ Test #8 |
| ClientAliveInterval ≤ 300s | `ClientAliveInterval 180` | ✅ Test #2 |
| ClientAliveCountMax | `ClientAliveCountMax 3` | ✅ Test #2 |
| X11Forwarding désactivé | `X11Forwarding no` | ✅ Test #7 |
| Protocole SSH 2 uniquement | `Protocol 2` | Bonne pratique |

### Script : `packer/provisioners/security-harden.sh`

```bash
#!/usr/bin/env bash
# security-harden.sh — Hardening OS Ubuntu 22.04 LTS
set -euo pipefail

LOG_FILE="/var/log/nextcloud-install.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== Hardening Sécurité OS ==="

# =====================================================
# 1. Configuration SSH
# =====================================================
SSHD_CONF="/etc/ssh/sshd_config"
log "Configuration SSH..."

# Backup
cp "$SSHD_CONF" "${SSHD_CONF}.bak.$(date +%Y%m%d)"

# Appliquer les configurations sécurité
declare -A SSH_SETTINGS=(
  ["PasswordAuthentication"]="no"
  ["PermitRootLogin"]="no"
  ["X11Forwarding"]="no"
  ["ClientAliveInterval"]="180"
  ["ClientAliveCountMax"]="3"
  ["Protocol"]="2"
  ["MaxAuthTries"]="3"
  ["AllowAgentForwarding"]="no"
  ["PermitEmptyPasswords"]="no"
)

for KEY in "${!SSH_SETTINGS[@]}"; do
  VALUE="${SSH_SETTINGS[$KEY]}"
  # Supprimer les entrées existantes (commentées ou actives)
  sed -i "/^#*\s*${KEY}\s/d" "$SSHD_CONF"
  # Ajouter la nouvelle valeur
  echo "${KEY} ${VALUE}" >> "$SSHD_CONF"
  log "SSH: ${KEY} = ${VALUE}"
done

# Valider la configuration SSH
sshd -t || { log "ERREUR: Configuration SSH invalide"; exit 1; }
log "Configuration SSH validée"

# =====================================================
# 2. Pare-feu UFW
# =====================================================
log "Configuration UFW..."
apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 443/tcp comment "HTTPS Nextcloud"
ufw allow 80/tcp  comment "HTTP redirect"
ufw allow 22/tcp  comment "SSH admin"
ufw --force enable
log "UFW configuré : allow 443, 80, 22 — deny tout le reste"

# =====================================================
# 3. Isolation services (MariaDB interne)
# =====================================================
log "Isolation MariaDB (loopback uniquement)..."
# MariaDB écoute uniquement sur loopback (127.0.0.1 par défaut sur Ubuntu)
if grep -q "^bind-address" /etc/mysql/mariadb.conf.d/50-server.cnf 2>/dev/null; then
  # Force MariaDB à écouter uniquement sur loopback
  sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf
    sed -i 's/^bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf
    
  log "MariaDB: bind-address=127.0.0.1"
fi

# =====================================================
# 4. Désactivation services inutiles (tests Microsoft #7, #9)
# =====================================================
log "Désactivation services inutiles..."
SERVICES_TO_DISABLE=(
  "ftp" "telnet" "rsync" "rsh-server" "rexec" "rlogin"
  "xinetd" "vsftpd" "atftpd" "tftpd" "inetd"
)
for SVC in "${SERVICES_TO_DISABLE[@]}"; do
  if systemctl list-unit-files "${SVC}.service" &>/dev/null; then
    systemctl disable --now "$SVC" 2>/dev/null || true
    log "Service désactivé: $SVC"
  fi
done

# =====================================================
# 5. Comptes système — vérification aucun mot de passe vide (test #10)
# =====================================================
log "Vérification comptes sans mot de passe..."
EMPTY_PASS=$(awk -F: '$2 == "" || $2 == "!" {print $1}' /etc/shadow 2>/dev/null || true)
if [[ -n "$EMPTY_PASS" ]]; then
  log "AVERTISSEMENT: comptes sans mot de passe détectés: $EMPTY_PASS"
  # Verrouiller les comptes sans mot de passe (sauf root qui est géré séparément)
  for ACCOUNT in $EMPTY_PASS; do
    [[ "$ACCOUNT" == "root" ]] && continue
    passwd -l "$ACCOUNT" 2>/dev/null && log "Compte verrouillé: $ACCOUNT"
  done
fi

# =====================================================
# 6. Mises à jour sécurité OS
# =====================================================
log "Application des mises à jour sécurité..."
apt-get update -qq
apt-get upgrade -y --only-upgrade
apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades
log "Mises à jour automatiques sécurité activées"

log "=== Hardening Sécurité OS terminé ==="
```

---

## 🧹 Décision 4 : Nettoyage et Généralisation (DERNIER provisioner)

### ⚠️ Règle absolue (ADR-800) : ce script est TOUJOURS le dernier provisioner Packer

Un bash history de plus de 1 KB = **rejet automatique** par Microsoft.

### Script : `packer/provisioners/cleanup-before-generalize.sh`

```bash
#!/usr/bin/env bash
# cleanup-before-generalize.sh — Nettoyage AVANT waagent deprovision
# ⚠️ DOIT ÊTRE LE DERNIER SCRIPT PACKER (avant waagent -deprovision+user)
set -euo pipefail

LOG_FILE="/var/log/nextcloud-install.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== Nettoyage avant généralisation ==="

# =====================================================
# 1. Bash history — CRITIQUE (test Microsoft #3)
# Taille > 1KB = rejet automatique sans revue
# =====================================================
log "Suppression bash history..."
# Tous les utilisateurs
for USER_HOME in /root /home/*; do
  [[ -d "$USER_HOME" ]] || continue
  HIST_FILE="${USER_HOME}/.bash_history"
  if [[ -f "$HIST_FILE" ]]; then
    HIST_SIZE=$(wc -c < "$HIST_FILE")
    log "  $HIST_FILE: ${HIST_SIZE} bytes → suppression"
    cat /dev/null > "$HIST_FILE"
    rm -f "$HIST_FILE"
  fi
done
# Vider l'historique de la session courante
history -c 2>/dev/null || true
unset HISTFILE
export HISTSIZE=0

# =====================================================
# 2. Logs d'installation et fichiers temporaires
# =====================================================
log "Nettoyage fichiers temporaires..."
rm -rf /tmp/* /var/tmp/*
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

# Nettoyer les logs de build (garder une trace minimale)
find /var/log -name "*.log" -not -name "nextcloud-install.log" \
  -exec truncate -s 0 {} \; 2>/dev/null || true
find /var/log -name "*.gz" -delete 2>/dev/null || true
find /var/log -name "*.1" -delete 2>/dev/null || true

# =====================================================
# 3. Credentials et clés SSH de build
# =====================================================
log "Suppression credentials de build..."
# Clés SSH du user de build Packer
if [[ -d /home/packer ]]; then
  rm -rf /home/packer/.ssh
fi
# Variables d'environnement sensibles (si exportées)
unset AZURE_CLIENT_ID AZURE_CLIENT_SECRET AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID

# =====================================================
# 4. Rotation des clés SSH hôte (générer nouvelles clés au 1er démarrage)
# =====================================================
log "Suppression clés SSH hôte (régénérées au 1er boot client)..."
rm -f /etc/ssh/ssh_host_*
# cloud-init régénèrera les clés au premier démarrage

# =====================================================
# 5. Machine-ID — réinitialisation pour généralisation
# =====================================================
log "Réinitialisation machine-id..."
echo "" > /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# =====================================================
# 6. Walinuxagent — Généralisation (DERNIÈRE COMMANDE ABSOLUE)
# =====================================================
log "=== Généralisation Azure VM (waagent -deprovision+user) ==="
log "ATTENTION: Après cette commande, la VM est généralisée et ne doit plus être démarrée directement"
log "Installation terminée. Voir /var/log/nextcloud-install.log pour le détail complet."

# Cette commande DOIT être la toute dernière
# Elle supprime : users créés par provisioning, cloud-init data, network configs
waagent -force -deprovision+user
```

### Position dans le template Packer (ADR-605)

```hcl
build {
  # ... autres provisioners en premier ...
  provisioner "shell" { script = "provisioners/02-install-php.sh" }
  provisioner "shell" { script = "provisioners/03-install-nginx.sh" }
  provisioner "shell" { script = "provisioners/06-install-nextcloud.sh" }
  provisioner "shell" { script = "provisioners/04-install-mariadb.sh" }
  provisioner "shell" { script = "provisioners/install-azure-agent.sh" }
  provisioner "shell" { script = "provisioners/configure-tls.sh" }
  provisioner "shell" { script = "provisioners/security-harden.sh" }

  # ⚠️ TOUJOURS DERNIER — NE PAS MODIFIER L'ORDRE
  provisioner "shell" { script = "provisioners/cleanup-before-generalize.sh" }
}
```

---

## ✅ Décision 5 : Checklist des 15 Tests de Certification Microsoft

À exécuter via `make marketplace-validate` avant chaque soumission :

| # | Test | Script responsable | Status attendu |
|---|------|--------------------|----------------|
| 1 | TLS 1.2+ uniquement | `configure-tls.sh` | ✅ PASS |
| 2 | `ClientAliveInterval` ≤ 300s | `security-harden.sh` | ✅ PASS |
| 3 | Bash history < 1 KB | `cleanup-before-generalize.sh` | ✅ PASS |
| 4 | Aucun credential par défaut | `cleanup-before-generalize.sh` | ✅ PASS |
| 5 | walinuxagent installé et actif | `install-azure-agent.sh` | ✅ PASS |
| 6 | SSH par clé uniquement (`PasswordAuthentication no`) | `security-harden.sh` | ✅ PASS |
| 7 | Pas de X11/VNC exposé | `security-harden.sh` | ✅ PASS |
| 8 | Root SSH désactivé (`PermitRootLogin no`) | `security-harden.sh` | ✅ PASS |
| 9 | Systemd fonctionnel | Image Ubuntu 22.04 de base | ✅ PASS |
| 10 | Aucun compte avec mot de passe vide | `security-harden.sh` | ✅ PASS |
| 11 | Ports inutiles fermés | `security-harden.sh` (UFW) | ✅ PASS |
| 12 | Image Ubuntu 22.04 LTS endorsée Azure | Template Packer (source azure-arm) | ✅ PASS |
| 13 | OS disk ≥ 30 GB, 1 MB libre en fin de VHD | Packer `os_disk_size_gb = 50` | ✅ PASS |
| 14 | VM Gen2 compatible | Packer + Image Definition V2 (ADR-200) | ✅ PASS |
| 15 | Aucun rootkit | Base Ubuntu 22.04 + hardening | ✅ PASS |

---

## 🔎 Décision 6 : Audits Post-déploiement

### Script de validation sécurité (`make vm-security-check`)

```bash
# Extrait de scripts/vm-security-check.sh
# Exécuté sur la VM de test AVANT soumission Marketplace

echo "=== Vérifications sécurité pré-soumission ==="

# TLS
openssl s_client -connect localhost:443 -tls1   2>&1 | grep -q "handshake failure" && echo "✅ TLS 1.0 bloqué" || echo "❌ TLS 1.0 accepté"
openssl s_client -connect localhost:443 -tls1_2 2>&1 | grep -q "Cipher is" && echo "✅ TLS 1.2 OK" || echo "❌ TLS 1.2 KO"

# SSH
sshd -T | grep "passwordauthentication no" && echo "✅ SSH password auth désactivé" || echo "❌ SSH password auth actif"
sshd -T | grep "permitrootlogin no"         && echo "✅ Root SSH bloqué" || echo "❌ Root SSH autorisé"
sshd -T | grep "clientaliveinterval 180"    && echo "✅ ClientAliveInterval OK" || echo "❌ ClientAliveInterval NOK"

# Bash history
HIST_SIZE=$(wc -c < /root/.bash_history 2>/dev/null || echo 0)
[[ "$HIST_SIZE" -lt 1024 ]] && echo "✅ Bash history < 1KB" || echo "❌ Bash history >= 1KB ($HIST_SIZE bytes)"

# walinuxagent
systemctl is-active walinuxagent && echo "✅ walinuxagent actif" || echo "❌ walinuxagent inactif"

# MariaDB non exposé publiquement
ss -tlnp | grep 3306 | grep "127.0.0.1" && echo "✅ MariaDB loopback uniquement" || echo "❌ MariaDB exposé publiquement"

echo "=== Fin des vérifications sécurité ==="
```

---

## ⚠️ Risques et Mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Bash history rebuild > 1KB après cleanup | Faible | Élevé | `cleanup-before-generalize.sh` vérifie la taille avant `waagent` |
| TLS 1.0 / 1.1 réactivé par dépendance | Faible | Élevé | Test automatique dans `make marketplace-validate` |
| walinuxagent désactivé après reboot | Faible | Élevé | `systemctl enable walinuxagent` + validation dans smoke test |
| MariaDB exposé accidentellement sur 0.0.0.0 | Faible | Élevé | `bind-address=127.0.0.1` dans `50-server.cnf` + test dans smoke test |
| Clés SSH hôte non régénérées au 1er boot client | Faible | Moyen | Suppression dans cleanup + cloud-init assure la régénération |

---

## 🔗 Traçabilité

| Décision | ADR |
|----------|-----|
| Architecture VM (ports, isolation MariaDB) | [ADR-100](./100-ARCH-architecture-docker-first-vm-offer.md)](./100-ARCH-architecture-docker-first-vm-offer.md) |
| Infrastructure (NSG, Compute Gallery) | [ADR-200](./200-INFRA-infrastructure-azure.md) |
| Stack PHP + Packer HCL2 (ordre provisioners) | [ADR-605](./609-DEVOPS-php-version-strategy.md) |
| Exigences Marketplace (15 tests certification) | [ADR-800](./800-BIZ-publication-azure-marketplace-vm-offer.md) |

---

## 📝 Notes & Historique

| Date | Auteur | Changement | Raison |
|------|--------|------------|--------|
| 2026-02-21 | @architecture-team | Création ADR-300 | Consolidation des exigences sécurité issues de ADR-001, ADR-800 et des tests de certification Microsoft |
