# Plan d'adaptation des ADRs : SMW-Marketplace → Nextcloud-Marketplace

**Date de création :** 2026-05-21  
**Contexte :** Les ADRs actuels ont été importés du projet `smw-marketplace` (publication de SemanticMediaWiki sur Azure Marketplace). Ce plan décrit les travaux nécessaires pour les adapter au projet `nextcloud-marketplace` (publication de Nextcloud sur Microsoft Azure Marketplace).

---

## 1. Contexte et enjeux

### Projet source (SMW)
- Application : SemanticMediaWiki (extension PHP de MediaWiki)
- Stack : PHP, MediaWiki, extensions SMW
- Base de données : intégrée via MediaWiki
- Dépendances légères, application monolithique simple

### Projet cible (Nextcloud)
- Application : Nextcloud (plateforme de collaboration et partage de fichiers)
- Stack : PHP 8.x, Nextcloud Hub, base de données (MySQL/MariaDB ou PostgreSQL), cache Redis optionnel
- Services supplémentaires : base de données dédiée, potentiellement Redis, Nginx ou Apache
- Application plus complexe avec plus de services à orchestrer
- Licence AGPL-3.0 (vs GPL-2.0 pour SMW)

### Implications principales
| Dimension | SMW | Nextcloud |
|-----------|-----|-----------|
| Complexité infra | Simple (1 service) | Modérée (DB + app + optionnel cache) |
| Version PHP | 7.4–8.2 | 8.1+ (Nextcloud 27+) |
| Licence OSS | GPL-2.0 | AGPL-3.0 |
| SSO supporté | Via MediaWiki | SAML, LDAP, OAuth2 natif |
| Sécurité spécifique | Via MediaWiki | Hardening Nextcloud propre |
| Titre marketplace | SemanticMediaWiki | Nextcloud |

---

## 2. Classification des ADRs par effort d'adaptation

### Légende
| Niveau | Description |
|--------|-------------|
| 🟢 **Mineur** | Renommage et ajustements de références, structure identique |
| 🟡 **Modéré** | Modifications substantielles de contenu, logique conservée |
| 🔴 **Majeur** | Réécriture quasi-complète, logique différente |

---

## 3. Plan par ADR

### Phase 1 — META (fondations du projet)

| # | Fichier | Effort | Description des changements requis |
|---|---------|--------|-------------------------------------|
| 1 | `000-META-processus-creation-adr.md` | 🟢 Mineur | Remplacer `smw-marketplace` → `nextcloud-marketplace` dans les références. Contenu procédural générique applicable tel quel. |
| 2 | `001-META-definition-projet-smw-marketplace.md` | 🔴 Majeur | Réécriture complète : objectifs, périmètre, contraintes, stack technique, public cible, licence. Renommer en `001-META-definition-projet-nextcloud-marketplace.md`. |
| 3 | `002-META-agent-ia-non-hallucination.md` | 🟢 Mineur | Mettre à jour les références de projet. Ajouter les sources officielles Nextcloud (nextcloud.com, docs.nextcloud.com). |

**Livrable Phase 1 :** Socle documentaire aligné sur le projet Nextcloud.

---

### Phase 2 — INFRA (infrastructure Azure)

| # | Fichier | Effort | Description des changements requis |
|---|---------|--------|-------------------------------------|
| 4 | `200-INFRA-azure-infrastructure-vm-offer.md` | 🟡 Modéré | La structure VM/Compute Gallery/NSG/ARM reste identique. Adapter les tailles de VM recommandées (Nextcloud est plus gourmand : min 2 vCPU, 4 GB RAM). Adapter les règles NSG (port 443 HTTPS, potentiellement 80 pour redirect). Revoir les prérequis disque (Nextcloud : stockage données utilisateurs = volume plus important). |

**Livrable Phase 2 :** Architecture infra dimensionnée pour Nextcloud.

---

### Phase 3 — SEC (sécurité)

| # | Fichier | Effort | Description des changements requis |
|---|---------|--------|-------------------------------------|
| 5 | `300-SEC-securite-hardening-vm-certification.md` | 🟡 Modéré | Le hardening OS de base reste valide. Ajouter le hardening spécifique Nextcloud : permissions sur `/var/www/nextcloud`, configuration `config.php` sécurisée, headers HTTP (`X-Frame-Options`, CSP, HSTS). |
| 6 | `300-SEC-securite-image-vm.md` | 🟡 Modéré | Adapter la liste des paquets installés (supprimer les paquets MediaWiki, ajouter les dépendances Nextcloud). Vérifier le scan antivirus (Nextcloud a ClamAV intégré optionnel). |
| 7 | `302-SEC-sso-microsoft-entra-id.md` | 🔴 Majeur | Nextcloud supporte nativement SAML, OIDC et LDAP. Réécrire pour documenter l'intégration avec Microsoft Entra ID via l'app Nextcloud SSO & SAML ou via l'app OIDC. Documenter la configuration des attributs (email, displayname, groups). |
| 8 | `303-SEC-rbac-permissions-partner-center-gallery.md` | 🟢 Mineur | Contenu relatif à Partner Center/Compute Gallery, non spécifique à SMW. Mettre à jour les références de projet uniquement. |

**Livrable Phase 3 :** Politique de sécurité adaptée à Nextcloud et à ses besoins SSO.

---

### Phase 4 — DEVOPS (outillage et automatisation)

| # | Fichier | Effort | Description des changements requis |
|---|---------|--------|-------------------------------------|
| 9 | `600-DEVOPS-bootstrap-configuration-management.md` | 🟡 Modéré | Adapter les scripts de bootstrap pour installer Nextcloud (PHP + extensions requises, Nextcloud CLI `occ`, configuration base de données). |
| 10 | `601-DEVOPS-nomenclature-scripts.md` | 🟢 Mineur | Remplacer les préfixes `smw-` → `nc-` ou `nextcloud-`. Mettre à jour les exemples de noms de scripts. |
| 11 | `602-DEVOPS-makefile-orchestrateur.md` | 🟡 Modéré | Les cibles Makefile de base (build, test, deploy) restent valides. Adapter les targets spécifiques à l'application (ex. cibles de mise à jour Nextcloud, `occ maintenance:mode`). |
| 12 | `603-DEVOPS-git-workflow-et-strategie-versioning.md` | 🟢 Mineur | Adapter les conventions de versioning pour suivre les releases Nextcloud (ex. `IMAGE_VERSION=30.0.2-1` = Nextcloud 30.0.2, build 1). |
| 13 | `604-DEVOPS-modularisation-scripts-partages.md` | 🟢 Mineur | Structure de modularisation générique. Mettre à jour les exemples de modules (remplacer les modules SMW par des modules Nextcloud : db-setup, app-install, occ-config). |
| 14 | `607-DEVOPS-procedure-version-bump.md` | 🟡 Modéré | Adapter la procédure pour suivre les versions Nextcloud. Intégrer la vérification des changelogs Nextcloud et des security advisories. |
| 15 | `608-DEVOPS-non-duplication-fonctionnelle-transversale.md` | 🟢 Mineur | Contenu générique (principe DRY). Mettre à jour les références et exemples. |
| 16 | `609-DEVOPS-php-version-strategy.md` | 🔴 Majeur | Réécriture substantielle : Nextcloud impose des contraintes PHP strictes (ex. Nextcloud 29+ requiert PHP 8.1+, Nextcloud 31+ requiert PHP 8.2+). Documenter la matrice de compatibilité Nextcloud ↔ PHP et la stratégie de mise à jour. |
| 17 | `611-DEVOPS-gestion-couleurs-scripts-make.md` | 🟢 Mineur | Contenu générique (UX terminale). Aucun changement fonctionnel, mise à jour des références de projet. |
| 18 | `613-DEVOPS-provisioner-architecture-validation.md` | 🔴 Majeur | Réécriture complète des 8 provisioners Packer. L'architecture séquentielle est réutilisable, mais le contenu de chaque étape change totalement : installer PHP + extensions Nextcloud, créer la base de données, déployer Nextcloud, configurer `occ`, trusted domains, etc. |
| 19 | `614-DEVOPS-dev-vm-iteration-workflow.md` | 🟡 Modéré | Workflow d'itération VM généralement applicable. Adapter les commandes de vérification (remplacer les checks SMW par des checks Nextcloud : `occ status`, accès web, santé de la DB). |
| 20 | `616-DEVOPS-blob-storage-cache-packages-packer.md` | 🟢 Mineur | Mécanisme de cache des paquets génériquement applicable. Mettre à jour la liste des paquets mis en cache (archives Nextcloud, paquets PHP pour Nextcloud). |
| 21 | `617-DEVOPS-packer-outil-construction-images-vm.md` | 🟡 Modéré | La structure HCL Packer est réutilisable. Adapter les variables (IMAGE_NAME, IMAGE_VERSION), la liste des provisioners, et les post-processors si nécessaire. |
| 22 | `618-DEVOPS-strategie-debug-post-image-vm.md` | 🟡 Modéré | Stratégie de debug applicable. Adapter les commandes de diagnostic (logs Nextcloud dans `/var/log/nextcloud/`, `occ check`, accès admin). |

**Livrable Phase 4 :** Pipeline DevOps complet adapté à Nextcloud.

---

### Phase 5 — TEST (qualification et certification)

| # | Fichier | Effort | Description des changements requis |
|---|---------|--------|-------------------------------------|
| 23 | `700-TEST-plan-tests-integration.md` | 🔴 Majeur | Réécriture des cas de test : vérification de l'installation Nextcloud (accès web, wizard de configuration, création admin), tests des services (DB, PHP-FPM, Nginx/Apache), tests de performance de base, tests de sécurité (headers HTTP, HTTPS). |
| 24 | `701-TEST-protocole-qualification-post-image-vm.md` | 🔴 Majeur | Réécriture du protocole : checklist Nextcloud spécifique, vérifications `occ`, tests de connectivité, validation des credentials par défaut, conformité aux exigences de certification Azure Marketplace. |

**Livrable Phase 5 :** Protocole de qualification adapté à Nextcloud.

---

### Phase 6 — BIZ (publication et conformité marketplace)

| # | Fichier | Effort | Description des changements requis |
|---|---------|--------|-------------------------------------|
| 25 | `800-BIZ-publication-azure-marketplace-vm-offer.md` | 🟡 Modéré | La structure de publication (Partner Center, plan, SKU, GTM) reste identique. Adapter : catégorie d'offre (Storage & Backup, ou Productivity), description produit, screenshots, logo Nextcloud, politique de support. |
| 26 | `801-BIZ-strategie-documentation-marketplace.md` | 🟡 Modéré | Adapter la documentation utilisateur (guide de démarrage Nextcloud, configuration post-déploiement). Pointer vers docs.nextcloud.com. |
| 27 | `802-BIZ-sources-officielles-azure-marketplace.md` | 🟢 Mineur | Ajouter les sources officielles Nextcloud (nextcloud.com, GitHub nextcloud/server). Conserver les sources Azure. |
| 28 | `803-BIZ-titre-offre-marketplace-conformite-marque.md` | 🔴 Majeur | Réécriture complète : règles de marque Nextcloud (nextcloud.com/trademarks), titre conforme, contraintes de naming pour la Compute Gallery (ex. `nextcloud_image`). Vérifier la politique de marque Nextcloud pour les offres commerciales. |

**Livrable Phase 6 :** Offre marketplace prête pour soumission.

---

### Fichiers système (README, TAXONOMY, template)

| # | Fichier | Effort | Description des changements requis |
|---|---------|--------|-------------------------------------|
| 29 | `README.md` | 🟢 Mineur | Mettre à jour l'index des ADRs avec les nouveaux titres, supprimer les références SMW. |
| 30 | `TAXONOMY.md` | 🟢 Mineur | La taxonomie est générique. Mettre à jour l'exemple de projet. |
| 31 | `adr-template-ai-optimized.md` | 🟢 Mineur | Mettre à jour les exemples dans le template (remplacer SMW par Nextcloud dans les exemples). |

---

## 4. Synthèse par effort

| Effort | Nombre d'ADRs | ADRs concernés |
|--------|--------------|----------------|
| 🟢 Mineur (15 min–1h) | 14 | 000, 002, 303, 601, 603, 604, 608, 611, 616, 802, README, TAXONOMY, template, 617* |
| 🟡 Modéré (1h–3h) | 10 | 200, 300-hardening, 300-image, 602, 607, 614, 617, 618, 800, 801 |
| 🔴 Majeur (3h–8h) | 7 | 001, 302, 609, 613, 700, 701, 803 |

---

## 5. Ordre de traitement recommandé

L'ordre suit les dépendances logiques : définir d'abord la vision, puis l'infrastructure, puis les outils, puis les tests, puis le business.

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
  META       INFRA      SEC       DEVOPS     TEST      BIZ
```

**Priorité absolue (bloquants) :**
1. `001` — Définition projet (tout dépend de ce cadrage)
2. `613` — Architecture provisioners (cœur du build)
3. `609` — Stratégie PHP (contrainte technique fondamentale)

**Priorité haute :**
4. `302` — SSO Entra ID (requis pour la certification)
5. `700` + `701` — Tests et qualification (requis pour la publication)
6. `803` — Titre et marque (requis pour Partner Center)

---

## 6. Points d'attention spécifiques à Nextcloud

### 6.1 Licence
Nextcloud est sous **AGPL-3.0**. Vérifier les implications pour la publication commerciale sur Azure Marketplace (les offres AGPL sont autorisées mais doivent mentionner la licence).

### 6.2 Marque Nextcloud
Nextcloud GmbH protège activement sa marque. Consulter [nextcloud.com/trademarks](https://nextcloud.com/trademarks) avant de finaliser le titre de l'offre. Le mot "Nextcloud" peut être utilisé dans des titres descriptifs du type *"Nextcloud on Ubuntu"*.

### 6.3 Architecture de la VM
Nextcloud nécessite plusieurs composants :
- **Web server** : Apache ou Nginx
- **PHP-FPM** : 8.1+ avec extensions (gd, curl, mbstring, xml, zip, bz2, intl, sodium, pdo, pdo_mysql, etc.)
- **Base de données** : MariaDB/MySQL (intégré dans la VM) ou PostgreSQL
- **Cache optionnel** : Redis (fortement recommandé pour les performances)

Cette architecture est plus complexe que SMW. Décider si la DB est dans la même VM ou externalisée (pour Marketplace, la VM autonome est généralement préférable pour la simplicité).

### 6.4 Wizard de première installation
Contrairement à SMW, Nextcloud nécessite une étape de configuration initiale (wizard web ou via `occ maintenance:install`). Décider si l'image est livrée pre-configured ou si le wizard est présenté à l'utilisateur au premier démarrage.

### 6.5 Versions Nextcloud à cibler
Nextcloud maintient deux branches simultanément (ex. Nextcloud 29 LTS + Nextcloud 30 stable). Définir quelle branche cibler et la stratégie de mise à jour de l'image.

---

## 7. Nouveaux ADRs potentiels à créer

Les éléments suivants n'ont pas d'équivalent dans le projet SMW et devront faire l'objet de nouveaux ADRs :

| ID suggéré | Titre | Justification |
|------------|-------|---------------|
| `201-INFRA-architecture-services-vm-nextcloud.md` | Architecture multi-services dans la VM | Nextcloud nécessite DB + Web + PHP-FPM dans une seule VM marketplace |
| `304-SEC-nextcloud-config-securise.md` | Configuration `config.php` sécurisée | Paramètres de sécurité spécifiques à Nextcloud |
| `610-DEVOPS-nextcloud-occ-commands.md` | Utilisation de `occ` pour la configuration | L'outil CLI de Nextcloud est central dans l'automatisation |
| `702-TEST-tests-fonctionnels-nextcloud.md` | Tests fonctionnels Nextcloud post-déploiement | Login, upload fichier, partage, calendrier, etc. |

---

## 8. Fichiers à renommer

| Fichier actuel | Fichier cible |
|----------------|---------------|
| `001-META-definition-projet-smw-marketplace.md` | `001-META-definition-projet-nextcloud-marketplace.md` |

Tous les autres fichiers peuvent conserver leur numérotation et leur nom (la numérotation est indépendante du contenu applicatif).

---

## 9. Critères de complétion

Une ADR est considérée comme "adaptée" lorsque :
- [ ] Toutes les références à `smw-marketplace`, `SemanticMediaWiki`, `SMW`, `MediaWiki` ont été remplacées par les équivalents Nextcloud
- [ ] Le contenu technique est exact pour Nextcloud (pas d'informations héritées de SMW)
- [ ] Les décisions sont justifiées dans le contexte Nextcloud
- [ ] Les liens et sources pointent vers des ressources Nextcloud ou Azure à jour
- [ ] La frontmatter YAML est mise à jour (date, statut, tags)

---

*Ce plan sera mis à jour au fil des itérations.*
