# Étape 3 — Offer Listing

> Partner Center : Offer → **Offer listing**  
> Sources : [description-courte.md](../../nextcloud-azure-marketplace-doc/docs/marketplace/description-courte.md)
>           [description-longue.md](../../nextcloud-azure-marketplace-doc/docs/marketplace/description-longue.md)

---

## Marketplace listing — English (langue principale)

### Name (titre)

```
Cotechnoe Cloud Hub — Secure File Collaboration on Azure
```

Caractères : 57 / 200 ✅  
Décision : [ADR-803](../adr/803-BIZ-titre-offre-marketplace-conformite-marque.md)  
**N'utilise pas "Nextcloud" ni "Azure Virtual Machines"** — conforme 100.1.1.1 et 100.7.1.  
"Azure" seul (sans "Virtual Machines") est autorisé dans le titre.

---

### Search results summary (≤ 150 caractères)

> ⚠️ Limite réelle : **150 chars** (screenshot Partner Center : 149 restants avec "x")

```
Self-hosted Nextcloud Hub on Azure (Ubuntu 24.04 LTS): secure file sharing, video calls, online document editing, and SSO — fully pre-configured VM.
```

Caractères : 148 / 150 ✅

---

### Short description (≤ 2048 caractères)

> ⚠️ Limite réelle : **2048 chars** (screenshot Partner Center : 2047 restants avec "x")  
> Champ texte — pas de HTML. Affiché dans la page de détail de l'offre.

```
Cotechnoe Cloud Hub delivers a fully pre-configured Nextcloud server on Azure — ready to use in minutes. Deploy from Azure Marketplace, complete the first-boot wizard, and your organization's private file collaboration platform is live.

Included: secure file sync and sharing with desktop, mobile, and web clients; CalDAV/CardDAV servers for calendars and contacts. Nextcloud Hub 33 bundles Talk (video calls), Nextcloud Office (document editing), and SAML 2.0 / OIDC for Microsoft Entra ID — enable and configure from the Admin panel after first boot.

Ideal for universities managing research data, healthcare organizations requiring regional data residency, and enterprises replacing OneDrive or Google Drive with a self-hosted platform under full IT control. Recommended VM size: Standard_D2s_v3 for teams up to 50 users; Standard_D4s_v3 for larger deployments.

Built for organizations requiring data sovereignty: all data stays within your Azure subscription and region. No telemetry is sent to Cotechnoe. GDPR-compatible by design.

Security-hardened: SSH key authentication required, UFW firewall (ports 22, 80, 443 only), PostgreSQL bound to localhost, PHP-FPM under a dedicated non-root user, automatic HTTP-to-HTTPS redirect, HSTS, fail2ban (SSH + Nextcloud login protection), and automatic security updates.

First boot takes under 5 minutes: the guided wizard sets your domain and administrator credentials. Certbot is pre-installed — run it after deployment to obtain and auto-renew a Let's Encrypt certificate. Full documentation and support are available at the link below.

Software stack: Nextcloud Hub 33 · PHP-FPM 8.3 · PostgreSQL 16 · Redis 7 · Nginx · Ubuntu 24.04 LTS (supported until 2034 with ESM).

Nextcloud is a registered trademark of Nextcloud GmbH, Stuttgart, Germany. This offer is published by Cotechnoe and is not affiliated with or endorsed by Nextcloud GmbH.
```

Caractères : ~1890 / 2048 ✅

---

### Description (≤ 5000 caractères — HTML accepté)

> ⚠️ Limite réelle : **5000 chars** (screenshot Partner Center : 4999 restants avec "x")  
> Accepte le HTML : `<p>`, `<h2>`, `<ul>`, `<li>`, `<strong>`, `<em>`.

```html
<p>Cotechnoe Cloud Hub is a fully pre-configured, security-hardened Ubuntu VM that deploys Nextcloud Hub — the leading open-source file collaboration platform — directly from Azure Marketplace. Deploy from the Azure portal, complete the first-boot wizard, and your organization's private cloud is live in minutes, not days. All data stays within your Azure subscription.</p>

<h2>Who benefits</h2>
<ul>
  <li><strong>Universities and research institutions</strong> — store, share, and version research data, publications, and project files; integrate with Microsoft Entra ID for federated campus authentication; meet GDPR and institutional data sovereignty policies</li>
  <li><strong>Healthcare and life sciences organizations</strong> — keep patient data and clinical files within a specific Azure region; data never leaves your subscription; no third-party cloud provider involved</li>
  <li><strong>Enterprises replacing public cloud storage</strong> — eliminate per-user SaaS fees; migrate from OneDrive, Google Drive, or Dropbox to a self-hosted platform under full IT control</li>
  <li><strong>Government agencies and public-sector organizations</strong> — meet national data residency and sovereignty mandates; keep citizen data within your Azure subscription and region; integrate with existing identity providers via SAML 2.0 / OIDC</li>
  <li><strong>Non-profit organizations</strong> — replace costly per-user SaaS subscriptions with a self-hosted open-source platform; full collaboration suite (files, video, calendars, office editing) with no recurring licensing fees</li>
  <li><strong>SMBs and distributed teams</strong> — deploy a full collaboration suite (files, video, calendars, contacts, office editing) on a single VM with predictable Azure compute costs</li>
</ul>

<h2>Key capabilities</h2>
<ul>
  <li><strong>Secure file sync and sharing</strong> — upload, share, and sync files from desktop, mobile, and web clients; versioning, recycling bin, and granular access control included</li>
  <li><strong>Calendars and contacts</strong> — CalDAV and CardDAV servers compatible with macOS, iOS, Outlook, and Android; shared calendars and address books included</li>
  <li><strong>HTTPS with modern TLS</strong> — TLS 1.2/1.3 enforced, HTTP-to-HTTPS redirect, HSTS, OCSP stapling, and security headers (X-Frame-Options, X-Content-Type-Options, Referrer-Policy) pre-configured in Nginx</li>
  <li><strong>Redis object cache</strong> — APCu local cache and Redis distributed/locking cache pre-configured; reduces database load and improves response time under concurrent users</li>
  <li><strong>Certbot pre-installed</strong> — run <code>certbot --nginx -d your.domain.com</code> after deployment to obtain and auto-renew a Let's Encrypt certificate; ACME challenge route already configured in Nginx</li>
  <li><strong>Rich app ecosystem</strong> — Nextcloud Hub 33 includes Talk (video calls), Nextcloud Office (document editing), and Entra ID / SAML integration as built-in apps; enable and configure from the Admin panel after first boot</li>
</ul>

<h2>What is included</h2>
<ul>
  <li><strong>Nextcloud Hub 33</strong> — the latest stable release of the leading open-source file collaboration platform, trusted by over 400,000 organizations worldwide</li>
  <li><strong>PHP-FPM 8.3</strong>, <strong>PostgreSQL 16</strong>, <strong>Redis 7</strong>, and <strong>Nginx 1.24</strong> — a performance-tuned, production-ready stack</li>
  <li><strong>Ubuntu 24.04 LTS</strong> — long-term supported base OS, supported until April 2029 (standard) and 2034 (ESM)</li>
  <li>Redis object cache pre-configured — reduces database load and improves response time under concurrent users</li>
  <li>Self-signed HTTPS certificate generated at image build time — replace with a Let's Encrypt certificate using the pre-installed Certbot, or supply your own CA-signed certificate</li>
</ul>

<h2>Security posture</h2>
<ul>
  <li>SSH key authentication enforced — password login disabled at the OS level; root login prohibited</li>
  <li>UFW firewall: only ports 22 (SSH), 80 (HTTP redirect), and 443 (HTTPS) open by default</li>
  <li>PostgreSQL bound to localhost — the database is accessible only via Unix socket or 127.0.0.1, never exposed to the network</li>
  <li>PHP-FPM running as <code>www-data</code>, a dedicated non-root system user with minimal privileges</li>
  <li>Automatic HTTP to HTTPS redirect; HSTS (max-age=15768000, includeSubDomains) pre-configured in Nginx</li>
  <li>fail2ban configured for SSH (maxretry=5, bantime=1h) and Nextcloud login failures (maxretry=10)</li>
  <li>Automatic security updates via unattended-upgrades (security origin only, no automatic reboot)</li>
  <li>Built and validated against Azure Marketplace certification requirements</li>
</ul>

<h2>Data sovereignty and compliance</h2>
<p>All data — files, user accounts, calendars, contacts, and configuration — resides exclusively within your Azure subscription and the Azure region you select. Cotechnoe has no access to your data. Fully compatible with GDPR obligations for EU-based deployments. No telemetry or data is sent to Cotechnoe.</p>

<h2>Get started in minutes</h2>
<p>Select a VM size — Standard_B2ms for evaluation, Standard_D2s_v3 (recommended default) or larger for production — deploy from Azure Marketplace, and complete the first-boot wizard to set your domain and administrator credentials. Full documentation is available at the support link below.</p>

<p><em>Nextcloud is a registered trademark of Nextcloud GmbH, Stuttgart, Germany. This offer is published by Cotechnoe and is not affiliated with or endorsed by Nextcloud GmbH.</em></p>
```

Caractères : ~4200 / 5000 ✅

---

### Privacy policy URL

```
https://github.com/Cotechnoe/nextcloud-azure-marketplace-doc/blob/main/PRIVACY.md
```

---

### Useful links

| Titre | URL |
|-------|-----|
| Documentation | `https://github.com/Cotechnoe/nextcloud-azure-marketplace-doc/wiki` |
| Release notes | `https://github.com/Cotechnoe/nextcloud-azure-marketplace-doc/blob/main/docs/marketplace/release-notes-v1.md` |

---

### Support contact

| Champ | Valeur |
|-------|--------|
| **Name** | Cotechnoe Support |
| **Email** | support@cotechnoe.com |
| **URL** | `https://github.com/Cotechnoe/nextcloud-azure-marketplace-doc/wiki/Support` |

---

### Engineering contact

| Champ | Valeur |
|-------|--------|
| **Name** | Cotechnoe Engineering |
| **Email** | engineering@cotechnoe.com |

---

### Marketplace media — Logos

| Format | Taille | Fichier |
|--------|--------|---------|
| Small | 48 × 48 px PNG | `logo-48x48.png` |
| Medium | 90 × 90 px PNG | `logo-90x90.png` |
| Large | 216 × 216 px PNG | `logo-216x216.png` ← **obligatoire** |

> Source des logos : dossier `assets/` à créer ou dans le dépôt doc.

---

### Screenshots (5 × 1280×720 px PNG)

| # | Fichier | Contenu |
|---|---------|---------|
| 1 | `screenshot-01-dashboard.png` | Nextcloud Files view (HTTPS visible) |
| 2 | `screenshot-02-admin-dashboard.png` | Admin Overview — tous les checks verts |
| 3 | `screenshot-03-https-certificate.png` | Cadenas + certificat Let's Encrypt |
| 4 | `screenshot-04-talk.png` | Nextcloud Talk (vidéoconférence) |
| 5 | `screenshot-05-collabora.png` | Collabora Online — édition document |

Voir : [screenshots-guide.md](../../nextcloud-azure-marketplace-doc/docs/marketplace/screenshots-guide.md)

---

### Search keywords (≤ 20)

```
Nextcloud, file sharing, collaboration, self-hosted, open-source,
HTTPS, SSO, Entra ID, SAML, OIDC, MariaDB, Nginx, PHP, Redis,
cloud storage, privacy, GDPR, AGPL, groupware, video conferencing
```

20 mots-clés ✅
