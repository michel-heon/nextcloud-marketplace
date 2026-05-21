---
adr: 700
title: "Plan de Tests d'Intégration — SMW Marketplace"
status: "accepted"
date: 2026-05-12
superseded_by: null
replaces: null
related_adrs: [200, 300, 302, 600, 601, 602, 611, 613, 614, 617, 800]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "test"
  impact: "high"
  quality:
    - "reliability"
    - "security"
    - "compliance"
    - "maintainability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "packer"
    - "bash"
    - "mediawiki"
    - "semantic-mediawiki"
    - "apache"
    - "mysql"
    - "tls"

tags: ["test", "integration", "e2e", "static-analysis", "provisioner", "security", "idempotence", "certification"]
stakeholders: ["@devops-team", "@dev-team", "@architecture-team"]
effort: "medium"
---

# ADR-700 : Plan de Tests d'Intégration — SMW Marketplace

## 📋 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-05-12 |
| **Stakeholders** | @devops-team, @dev-team |
| **Impact** | 🔴 Élevé (validation complète avant publication Marketplace) |
| **Effort** | 🟡 Moyen |
| **Risque technique** | 🟡 Moyen |

---

## 🎯 Contexte

Le projet produit une image VM Azure Marketplace via 9 provisioners Packer séquentiels
(ADR-613). L'image doit satisfaire simultanément :

- La **certification AMAT** (Azure Marketplace Certification Tool) — ADR-300, ADR-800
- Les critères de **sécurité OS** : SSH par clé uniquement, TLS 1.2+, UFW (22+443)
- L'**absence de credentials** dans l'image généralisée — US-02.4
- L'**idempotence du firstboot** (`smw-firstboot.service`) — US-02.3
- La **lisibilité du journal firstboot** via `journalctl` — US-02.5

Aujourd'hui, il n'existe pas de suite de tests structurée qui couvre ces exigences de
manière reproductible. Les tests manuels sont coûteux (30–60 min/cycle) et sujets à l'oubli.

---

## 💡 Décision

Adopter une **stratégie de tests en 3 phases** progressives, chacune ciblant un niveau
de risque distinct :

| Phase | Nom | Prérequis Azure | Durée | Déclencheur |
|-------|-----|-----------------|-------|-------------|
| 1 | Statique | ❌ Aucun | < 1 min | À chaque `git push` |
| 2 | Image Gallery | VM de test SSH | ~5 min | Après `make vm-build` |
| 3 | E2E Post-Deploy | VM ARM déployée | ~10 min | Avant publication |

Implémentation : un script unique `packer/scripts/integration-test.sh` avec
sous-commandes `static`, `image`, `e2e`, `all`, appelé depuis le Makefile (ADR-602).

---

## 📐 Architecture des Tests

### Phase 1 — Tests Statiques (T-STATIC)

**Objectif** : détecter les erreurs sans consommer de ressources cloud.

| ID | Test | Référence | Commande |
|----|------|-----------|----------|
| T-STATIC-01 | Packer HCL2 syntaxe valide | ADR-617, US-01.2 | `packer validate` |
| T-STATIC-02 | ARM `mainTemplate.json` JSON valide | ADR-200, US-02.1 | `python3 -m json.tool` |
| T-STATIC-03 | ARM `createUIDefinition.json` JSON valide | ADR-200, US-02.1 | `python3 -m json.tool` |
| T-STATIC-04 | Aucun credential hardcodé dans les provisioners | US-02.4 | `grep -riE` patterns passwords |
| T-STATIC-05 | Tous les provisioners sont exécutables | ADR-601 | `test -x` |
| T-STATIC-06 | Séquence 01→09 complète (9 scripts) | ADR-613 | `ls` pattern check |
| T-STATIC-07 | `smw-firstboot.service` déclaré dans `08-firstboot-setup.sh` | US-02.3 | `grep` |
| T-STATIC-08 | Sentinel idempotence référencé dans `08-firstboot-setup.sh` | US-02.3 | `grep firstboot-done` |
| T-STATIC-09 | `trap ERR` présent dans `08-firstboot-setup.sh` | US-02.5 | `grep` |
| T-STATIC-10 | SSH hardening `PasswordAuthentication no` dans `07-security-harden.sh` | ADR-300 | `grep` |

**Critère de succès** : T-STATIC-01 à T-STATIC-10 tous PASS → merge autorisé.

---

### Phase 2 — Tests Image Gallery (T-IMAGE)

**Objectif** : valider l'état de l'image construite par Packer via SSH sur une VM de test
déployée depuis la gallery (`galSMWMarketplace`). Le firstboot **n'a pas encore été
déclenché** (sentinel absent).

| ID | Test | Référence | Assertion SSH |
|----|------|-----------|---------------|
| T-IMAGE-01 | PHP 8.2 installé | ADR-609, US-01.1 | `php8.2 --version \| grep '8\\.2'` |
| T-IMAGE-02 | Apache 2.4 installé | ADR-613 | `apache2 -v 2>&1 \| grep '2\\.4'` |
| T-IMAGE-03 | MySQL 8.x installé | ADR-001 | `mysql --version \| grep -E '8\\.'` |
| T-IMAGE-04 | MediaWiki présent (`/opt/mediawiki`) | ADR-613 | `test -d /opt/mediawiki` |
| T-IMAGE-05 | SMW 6.0.1 extensions présentes | ADR-001 | `test -d /opt/mediawiki/extensions/SemanticMediaWiki` |
| T-IMAGE-06 | `smw-firstboot.service` enabled | US-02.3 | `systemctl is-enabled smw-firstboot` |
| T-IMAGE-07 | Sentinel absent (image non bootée) | US-02.3 | `test ! -f /var/lib/smw/.firstboot-done` |
| T-IMAGE-08 | Pas de credentials MySQL dans `LocalSettings.php` | US-02.4 | `! grep -q 'wgDBpassword.*[^$\{]'` |
| T-IMAGE-09 | SSH `PasswordAuthentication no` (ADR-300) | ADR-300, US-03.2 | `grep -r 'PasswordAuthentication no' /etc/ssh/` |
| T-IMAGE-10 | UFW actif (ADR-300) | ADR-300 | `ufw status \| grep 'Status: active'` |

**Critère de succès** : T-IMAGE-01 à T-IMAGE-10 tous PASS → build gallery validé.

---

### Phase 3 — Tests E2E Post-Déploiement (T-E2E)

**Objectif** : valider le comportement complet après déploiement ARM client. Le firstboot
**a été exécuté** (sentinel présent).

| ID | Test | Référence | Méthode |
|----|------|-----------|---------|
| T-E2E-01 | SSH accessible (clé uniquement) | ADR-300, US-03.2 | `ssh key test -o BatchMode=yes` |
| T-E2E-02 | HTTP → HTTPS redirect 301/302 | ADR-300, US-02.2 | `curl -I http://<IP>/` |
| T-E2E-03 | HTTPS répond 200 | US-02.2 | `curl -sk https://<IP>/` |
| T-E2E-04 | Page login MediaWiki visible | US-02.2 | `curl -sk .../Special:UserLogin \| grep mediawiki` |
| T-E2E-05 | `smw-firstboot.service` complété | US-02.3 | `systemctl show --property=Result` |
| T-E2E-06 | Sentinel présent | US-02.3 | `test -f /var/lib/smw/.firstboot-done` |
| T-E2E-07 | Idempotence — relance → no-op | US-02.3 | Relancer service, vérifier sentinel intact |
| T-E2E-08 | `Special:SemanticMediaWiki` accessible | ADR-001 | `curl -sk .../Special:SemanticMediaWiki` |
| T-E2E-09 | `journalctl` entries firstboot présentes | US-02.5 | `journalctl -u smw-firstboot -n 1` |
| T-E2E-10 | TLS 1.0 désactivé | ADR-300, US-03.3 | `openssl s_client -tls1` → doit échouer |
| T-E2E-11 | Ports 22 et 443 ouverts, autres fermés | ADR-300 | `nc -z -w 3 <IP> <port>` |

**Critère de succès** : T-E2E-01 à T-E2E-11 tous PASS → prêt pour publication Preview.

---

## 🛠️ Implémentation

### Fichiers créés

```
packer/scripts/integration-test.sh   ← Script principal (ADR-601, ADR-602)
```

### Interface CLI

```bash
# Phase statique uniquement (sans Azure)
bash packer/scripts/integration-test.sh static

# Tests image gallery (VM SSH requise)
VM_NAME=smw-wiki-test E2E_RG=rg-smw-marketplace-e2e \
  bash packer/scripts/integration-test.sh image

# Tests E2E post-déploiement
bash packer/scripts/integration-test.sh e2e

# Suite complète
bash packer/scripts/integration-test.sh all
```

### Cibles Makefile (ADR-602, ADR-611)

```makefile
##@ Tests d'Intégration (ADR-700)
integration-test-static   ## Phase 1 — Tests statiques (local, aucun accès Azure)
integration-test-image    ## Phase 2 — Tests image gallery (SSH, après vm-build)
integration-test-e2e      ## Phase 3 — Tests E2E post-déploiement ARM
integration-test          ## Suite complète : phases 1 + 2 + 3
```

---

## 🔗 Conformité aux ADRs

| ADR | Conformité |
|-----|-----------|
| **ADR-001** | Versions canoniques vérifiées (PHP 8.2, MySQL 8.x, MW 1.43.x, SMW 6.0.1) |
| **ADR-300** | SSH clé uniquement, TLS 1.2+, UFW ports 22+443 validés (T-STATIC-10, T-IMAGE-09, T-E2E-10) |
| **ADR-601** | Script nommé `integration-test.sh` (objet-action, kebab-case) |
| **ADR-602** | Makefile délègue au script — règle des 3 lignes respectée |
| **ADR-611** | Couleurs `RED`/`GREEN`/`YELLOW`/`CYAN` via `printf`, aucun `echo -e` |
| **ADR-613** | Séquence 01→09, ownership, service conflicts couverts (T-STATIC-05..09, T-IMAGE) |
| **ADR-800** | Pré-requis certification AMAT couverts par T-IMAGE-09, T-E2E-10 |

---

## ⚠️ Limites et Hors-Périmètre

- **Tests de charge / performance** : hors scope (EPIC-06)
- **Validation Partner Center** : manuelle via `make marketplace-validate` (ADR-800)
- **CTT complet** : `make marketplace-all` (outil Microsoft externe)
- **Certificat Let's Encrypt** : nécessite un FQDN public — testé manuellement

---

## 🔄 Évolutions Futures

| Sprint | Évolution |
|--------|-----------|
| EPIC-03 | Intégrer les 15 contrôles AMAT (US-03.1) dans T-IMAGE |
| EPIC-06 | T-E2E-08 étendu aux smoke tests Preview complets (US-06.2) |
| CI/CD | GitHub Actions : `integration-test-static` à chaque PR |

---

## ✅ Conséquences

**Positives** :
- Détection précoce des régressions (phase statique < 1 min)
- Preuve de conformité avant chaque soumission Marketplace
- Couverture directe des critères d'acceptation des US-02.x et US-03.x

**Négatives / Contraintes** :
- Phase 2 et 3 nécessitent des ressources Azure actives (coût)
- Phase 3 dépend d'un déploiement ARM préalable (ADR-614 workflow recommandé)
