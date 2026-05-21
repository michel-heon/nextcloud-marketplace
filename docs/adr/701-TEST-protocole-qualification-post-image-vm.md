---
adr: 701
title: "Protocole de Qualification Post-Image : Critères d'Acceptation et Non-Régression"
status: "accepted"
date: 2026-05-15
superseded_by: null
replaces: null
related_adrs: [613, 618, 700, 800]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "test"
  impact: "high"
  quality:
    - "reliability"
    - "compliance"
    - "maintainability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "bash"
    - "playwright"
    - "nextcloud"
    - "nginx"

tags: ["qa", "qualification", "acceptance-criteria", "non-regression", "oracle", "post-image", "certification", "smoke-test", "e2e"]
stakeholders: ["@qa-team", "@devops-team", "@architecture-team"]
effort: "medium"
---

# ADR-701 : Protocole de Qualification Post-Image : Critères d'Acceptation et Non-Régression

**Statut**: Accepté
**Date**: 2026-05-15
**Auteur**: Copilot + Michel Héon

---

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date décision** | 2026-05-15 |
| **Stakeholders** | @qa-team, @devops-team |
| **Impact** | 🔴 Élevé (gate avant toute publication Marketplace) |
| **Effort** | 🟡 Moyen |
| **Risque technique** | 🟡 Moyen |

---

## 🎯 Contexte & Problème

### Le problème du "quand est-ce prêt ?" côté QA

ADR-700 définit les tests qui existent et quand les déclencher (3 phases : statique,
image, e2e). ADR-618 définit comment l'ingénieur DevOps diagnostique et corrige un
bug post-image. Mais aucun de ces ADRs ne répond à la question propre au QA :

> **Quels critères permettent de déclarer qu'une image VM est qualifiée — c'est-à-dire
> prête pour la publication Marketplace ou la livraison en production ?**

Cette question est structurellement différente du "quels tests existent" (ADR-700)
et du "comment corriger un bug" (ADR-618). Elle porte sur :

1. **L'oracle de qualification** : qu'est-ce qui constitue un signal de succès fiable ?
2. **Les niveaux de confiance** : smoke test ≠ qualification fonctionnelle ≠ certification
3. **Le protocole de re-qualification** : après un correctif (ADR-618 backport), que
   doit re-valider le QA, et dans quel ordre ?
4. **La non-régression** : comment garantir que les bugs corrigés ne réapparaissent pas ?

### Asymétrie entre l'auteur du correctif et son validateur

Sans protocole explicite, la validation d'un correctif est souvent réalisée par
la même personne qui l'a appliqué. Cette pratique crée un **biais de confirmation** :
le correcteur vérifie ce qu'il sait avoir changé, pas ce qu'il aurait pu casser.

Le QA doit pouvoir valider une image de manière **indépendante**, avec des critères
objectifs, sans connaître les détails internes du correctif appliqué.

---

## ✅ Décision

### Principe architectural : Qualification par niveaux de confiance avec oracle automatisé

Nous adoptons un **protocole de qualification en 3 niveaux progressifs**, chacun
apportant un niveau de confiance distinct et s'adressant à un risque spécifique :

```
  ┌─────────────────────────────────────────────────────────────────┐
  │  NIVEAU 1 — SMOKE QUALIFICATION (< 2 min)                       │
  │  Question : "La VM est-elle vivante et SSH accessible ?"         │
  │  Réponse suffisante pour : continuer la validation               │
  ├─────────────────────────────────────────────────────────────────┤
  │  NIVEAU 2 — QUALIFICATION FONCTIONNELLE (~10 min)                │
  │  Question : "Le service applicatif est-il opérationnel ?"        │
  │  Réponse suffisante pour : validation interne, démo, test QA     │
  ├─────────────────────────────────────────────────────────────────┤
  │  NIVEAU 3 — QUALIFICATION CERTIFIABLE (~30 min)                  │
  │  Question : "L'image satisfait-elle les exigences Marketplace ?" │
  │  Réponse suffisante pour : publication Azure Marketplace         │
  └─────────────────────────────────────────────────────────────────┘
```

**Règle cardinale** : aucune image ne progresse vers un niveau supérieur avant
d'avoir satisfait tous les critères du niveau inférieur.

---

### Niveau 1 — Smoke Qualification

**Objectif** : s'assurer que la VM a démarré correctement et que le plan de
contrôle est accessible. C'est la condition préalable à toute qualification.

| Critère | Signal de succès | Signal d'échec | Outil |
|---------|-----------------|----------------|-------|
| VM démarrée | State = `Running` | Timeout ou `Failed` | `az vm show` |
| SSH accessible | Connexion établie en < 30s | Timeout / refus | `ssh -o ConnectTimeout=30` |
| Service actif | `systemctl is-active` = `active` | `failed` ou `inactive` | SSH + systemctl |
| Firstboot terminé | Marqueur de fin présent | Absent ou erreur journald | SSH + journalctl |

**Résultat attendu** : 4/4 critères verts → qualification niveau 1 passée.

**En cas d'échec** : escalader vers ADR-618 (diagnostic post-image DevOps) avant
de poursuivre. Le QA documente le symptôme observé et le transmet.

---

### Niveau 2 — Qualification Fonctionnelle

**Objectif** : vérifier que le service applicatif répond correctement aux
scénarios utilisateur de base. Cette qualification peut être exécutée par
tout membre de l'équipe, QA ou DevOps.

La suite de tests E2E automatisés (Playwright, ADR-700 Phase 3) constitue
l'**oracle principal** de cette qualification :

| Test | Critère d'acceptation | Référence |
|------|----------------------|-----------|
| Connectivité HTTP/HTTPS | Réponse 200 ou redirection valide (pas d'erreur TLS) | T-BROWSER-00 |
| Page principale Nextcloud | Dashboard Nextcloud chargé, `status.php` répond | T-BROWSER-01 |
| Formulaire de connexion | Page login accessible et fonctionnelle | T-BROWSER-02 |
| App Nextcloud active | Apps activées listées via `/ocs/v1.php/apps` | T-BROWSER-03 |

**Résultat attendu** : 4/4 tests E2E verts → qualification niveau 2 passée.

**Interprétation des échecs** :

```
Échec T-BROWSER-00 (HTTPS) → problème TLS ou configuration serveur web
Échec T-BROWSER-01 (Dashboard) → problème Nextcloud ou base de données
Échec T-BROWSER-02 (login) → problème d'authentification ou session PHP
Échec T-BROWSER-03 (Apps) → apps Nextcloud non installées ou désactivées
```

Chaque échec est un symptôme traçable vers une couche de provisioner spécifique
(cf. matrice de traçabilité ADR-618).

---

### Niveau 3 — Qualification Certifiable

**Objectif** : vérifier la conformité aux exigences non-fonctionnelles et
Marketplace (ADR-800). Ce niveau requiert une checklist formelle.

| Domaine | Critère | Outil de vérification |
|---------|---------|----------------------|
| **Sécurité SSH** | Authentification par clé uniquement, pas de PermitRootLogin | `sshd -T \| grep` |
| **Pare-feu** | UFW actif, ports 22 et 443 uniquement ouverts | `ufw status` |
| **TLS** | Certificat valide, TLS 1.2+ uniquement | `openssl s_client` |
| **Credentials** | Aucun mot de passe en clair dans l'image | Scan scripts + image |
| **Idempotence firstboot** | Re-exécution de `nc-firstboot` ne casse pas le service | Re-run manuel + tests |
| **Généralisation** | Image dépersonnalisée (`waagent -deprovision`) | Vérif. `/etc/waagent.conf` |
| **AMAT** | Score de certification Marketplace ≥ seuil requis | Azure AMAT tool |

**Résultat attendu** : 7/7 critères verts → image qualifiée pour publication.

---

### Principe de Non-Régression

Chaque bug découvert et corrigé via le cycle ADR-618 **doit générer un test
permanent** dans la suite de qualification :

```
Bug détecté en post-image
         │
         ▼
Corrigé par ADR-618 (fix in-situ + backport provisioner)
         │
         ▼
QA évalue : ce bug est-il couvert par un test existant ?
         │
    NON  │  OUI
         │        └─→ Vérifier que le test échoue sur l'ancienne image
         ▼
Créer ou renforcer un test qui aurait détecté ce bug
         │
         ▼
Ajouter le test à la suite automatisée avant le merge du correctif
```

**Règle** : un correctif de provisioner sans test de non-régression correspondant
n'est pas considéré comme complet par le QA.

---

### Principe d'Indépendance du Validateur

La qualification d'une image produite suite à un correctif doit être
réalisée par une personne **distincte** de celle qui a appliqué le correctif,
ou à défaut, avec un délai et une revue formelle.

L'indépendance garantit que la validation couvre le comportement observable,
pas uniquement ce que le correcteur sait avoir changé.

En contexte solo ou équipe réduite : utiliser les tests automatisés comme
proxy d'indépendance — ils ne "connaissent" pas le correctif.

---

## 📊 Matrice de Décision Quantifiée

| Critère | Poids | Validation ad hoc | Tests uniquement (ADR-700) | **Ce protocole** |
|---------|-------|-------------------|---------------------------|-----------------|
| **Confiance dans la qualification** | 35% | 🔴 3/10 | 🟡 6/10 | 🟢 9/10 |
| **Traçabilité des critères d'acceptation** | 25% | 🔴 2/10 | 🟡 5/10 | 🟢 9/10 |
| **Reproductibilité inter-validateurs** | 20% | 🔴 2/10 | 🟢 8/10 | 🟢 9/10 |
| **Couverture de non-régression** | 20% | 🔴 1/10 | 🟡 5/10 | 🟢 8/10 |
| **Score Total Pondéré** | 100% | **2.20** | **6.05** | **8.85** ⭐ |

```
Validation ad hoc  : (3*0.35) + (2*0.25) + (2*0.20) + (1*0.20) = 2.20
Tests seuls (ADR-700): (6*0.35) + (5*0.25) + (8*0.20) + (5*0.20) = 6.05
Ce protocole       : (9*0.35) + (9*0.25) + (9*0.20) + (8*0.20) = 8.85 ✅
```

---

## ⚖️ Conséquences

### ✅ Positives (Bénéfices)

| Bénéfice | Description |
|----------|-------------|
| **Critères objectifs** | Le QA sait exactement quand déclarer une image "prête" |
| **Indépendance de validation** | Réduction du biais de confirmation |
| **Non-régression structurelle** | Les bugs corrigés ne reviennent pas silencieusement |
| **Complémentarité avec ADR-618** | Protocole QA = contrat de sortie du cycle DevOps |
| **Préparation certification AMAT** | Le niveau 3 constitue la checklist pré-certification |

### ⚠️ Négatives (Risques & Limitations)

| Risque | Mitigation |
|--------|-----------|
| Niveau 3 coûteux à chaque correctif mineur | Appliquer le niveau 3 uniquement avant publication, pas à chaque bugfix |
| Tests E2E peuvent être flaky (infra réseau) | Rejouer 2 fois avant de déclarer un échec |
| Critères AMAT changent avec les politiques Microsoft | Intégrer une veille Marketplace semestrielle |

---

## 🔄 Alternatives Considérées

### Alternative 1 : Déléguer entièrement à ADR-700 (tests existants)

ADR-700 définit déjà des phases de test. On pourrait considérer que "tests verts =
image qualifiée", sans protocole supplémentaire.

**Rejeté** : ADR-700 répond à "quels tests existent", pas à "quand déclarer prêt"
ni à "comment garantir la non-régression". L'oracle existe mais le protocole
d'interprétation manque.

### Alternative 2 : Checklist manuelle unique

Une checklist plate sans niveaux, remplie manuellement avant chaque publication.

**Rejeté** : ne différencie pas la validation interne de la certification Marketplace ;
coûteuse à exécuter entièrement pour un correctif mineur ; non automatisable.

---

## 🗺️ Relations avec les ADRs

```
ADR-613 (Provisioners)
    │
    │  produit une image
    ▼
ADR-617 (Packer build)
    │
    │  image déployée en VM
    ▼
ADR-618 (Debug post-image)  ──────────────────────────────────►  ADR-701 (QA)
    │  DevOps : corrige le bug                                      │  QA : valide la correction
    │  in-situ + backport provisioner                               │  via protocole 3 niveaux
    │                                                               │
    └───────────────────────────────────────────────────────────────┘
                        boucle de qualification

ADR-700 (Plan de tests)
    │
    │  fournit l'oracle automatisé (suite E2E)
    ▼
ADR-701 (Ce protocole)
    │
    │  gate de qualification validée
    ▼
ADR-800 (Publication Marketplace)
```

---

## 📚 Références

- [ADR-618](./618-DEVOPS-strategie-debug-post-image-vm.md) — Cycle de débogage post-image (perspective DevOps)
- [ADR-700](./700-TEST-plan-tests-integration.md) — Plan de tests d'intégration (suite E2E, phases 1-3)
- [ADR-613](./613-DEVOPS-provisioner-architecture-validation.md) — Architecture et validation des provisioners
- [ADR-800](./800-BIZ-publication-azure-marketplace-vm-offer.md) — Exigences de publication Azure Marketplace
- [Azure AMAT](https://docs.microsoft.com/azure/marketplace/azure-vm-certification-faq) — Azure Marketplace Certification Tool
