---
adr: 618
title: "Stratégie de Débogage Post-Image : Cycle Observation VM → Correction Provisioner"
status: "accepted"
date: 2026-05-15
superseded_by: null
replaces: null
related_adrs: [613, 614, 617, 700]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "medium"
  quality:
    - "maintainability"
    - "reliability"
    - "observability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "packer"
    - "bash"

tags: ["vm", "debug", "image-as-code", "observability", "provisioner", "feedback-loop", "post-image", "serial-console", "boot-diagnostics", "run-command"]
stakeholders: ["@devops-team", "@dev-team"]
effort: "low"
---

# ADR-618: Stratégie de Débogage Post-Image : Cycle Observation VM → Correction Provisioner

**Statut**: Accepté  
**Date**: 2026-05-15  
**Auteur**: Copilot + Michel Héon  

---

## 🎯 Contexte & Problème

### Le problème : deux classes de bugs distincts dans le cycle image-as-code

Un pipeline image-as-code (tel que Packer) distingue structurellement deux phases
d'exécution avec des modes de défaillance différents :

```
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 1 — Construction de l'image (build-time)                     │
│  packer build → provisioners s'exécutent → image capturée           │
│  Bugs détectés : erreurs de scripts, packages manquants, timeouts   │
├─────────────────────────────────────────────────────────────────────┤
│  PHASE 2 — Instanciation de la VM (runtime)                         │
│  az vm create → VM démarrée depuis l'image → service exposé         │
│  Bugs détectés : mauvaise configuration, service ne démarre pas,    │
│                  paramètre figé dans l'image, dépendance absente     │
└─────────────────────────────────────────────────────────────────────┘
```

Les bugs **post-image** sont particulièrement difficiles à tracer : la VM fonctionne
en apparence, mais le service applicatif échoue, se comporte incorrectement, ou
les tests automatisés échouent sans que la cause soit immédiatement évidente dans
les logs de construction.

### Le problème de la boucle naïve

L'approche réflexe consiste à modifier le provisioner et reconstruire l'image :

```
bug détecté → modifier provisioner (hypothèse) → packer build (30-60 min)
→ redéployer VM → re-tester → toujours bug ? → recommencer
```

Cette boucle est coûteuse (temps + coût cloud), non-traçable (la cause réelle
n'est pas confirmée avant le rebuild), et source d'itérations multiples sur des
hypothèses incorrectes.

---

## ✅ Décision

### Principe architectural : Observabilité-en-premier, correction-en-situ, backport confirmé

Nous adoptons un cycle de correction en trois temps obligatoires, appliqué à
tout bug détecté sur une VM dérivée d'une image construite :

```
      ┌─────────────────────────────────────────────────┐
      │  1. OBSERVER : accéder à la VM par le canal     │
      │     le plus direct disponible (escalade)        │
      └──────────────────┬──────────────────────────────┘
                         │
      ┌──────────────────▼──────────────────────────────┐
      │  2. CORRIGER IN-SITU : appliquer et valider     │
      │     le fix directement sur la VM vivante        │
      └──────────────────┬──────────────────────────────┘
                         │
      ┌──────────────────▼──────────────────────────────┐
      │  3. BACKPORTER : transcrire la correction       │
      │     confirmée dans la définition de l'image     │
      │     (provisioner), reconstruire, re-valider     │
      └─────────────────────────────────────────────────┘
```

**Règle cardinale** : aucune modification de provisioner ne doit être commitée
sans avoir préalablement validé le fix sur une VM vivante.

---

### Étape 1 — Observer : hiérarchie d'accès à la VM

L'accès à une VM défectueuse suit une hiérarchie croissante selon la nature
du problème :

| Niveau | Canal | Cas d'usage | Prérequis |
|--------|-------|-------------|-----------|
| 1 | **SSH direct** | VM accessible, service applicatif défaillant | Port 22 ouvert, clé présente |
| 2 | **Remote Command** (ex: `az vm run-command`) | SSH inaccessible (firewall, sshd cassé) | Accès au plan de contrôle cloud |
| 3 | **Serial Console** | VM ne boot pas, GRUB, kernel panic, iptables bloquant | Boot Diagnostics activé |
| 4 | **Boot Diagnostics** (screenshot + serial log) | État pré-login, diagnostic passif | Boot Diagnostics activé |

**Principe d'escalade** : commencer par le niveau 1 et monter uniquement si le
canal inférieur est inopérant. Ne pas sauter directement au niveau 4 (Boot
Diagnostics) pour un problème applicatif accessible via SSH.

**Boot Diagnostics** doit être **activé à la construction de l'image** (paramètre
dans la définition Packer), de sorte qu'il soit disponible sans intervention
manuelle lors de n'importe quel déploiement de débogage.

### Étape 2 — Corriger in-situ

Une fois l'accès établi, le diagnostic et la correction s'effectuent sur la VM
vivante avant tout rebuild :

1. **Identifier le symptôme** via les logs système (journald, logs applicatifs)
2. **Isoler la cause** (service, fichier de configuration, package, droits)
3. **Appliquer le fix manuellement** sur la VM
4. **Valider localement** que le fix corrige le symptôme
5. **Confirmer via les tests automatisés** (oracle de validation — cf. ADR-700)

Cette étape transforme une hypothèse en certitude : le fix est confirmé sur
l'environnement réel avant d'être intégré à la définition de l'image.

### Étape 3 — Backporter vers la définition d'image

Le fix validé in-situ est ensuite transcrit dans la couche appropriée :

```
Symptôme constaté              → Couche de définition à corriger
──────────────────────────────────────────────────────────────────
Package manquant               → Script d'installation (provisioner)
Fichier de configuration erroné → Script de configuration (provisioner)
Service non activé au boot     → Script systemd (provisioner)
Paramètre dépendant du contexte → Mécanisme de configuration à la création
                                  (cloud-init, user-data, extension VM)
```

**Principe de traçabilité** : chaque correctif intégré dans un provisioner doit
être accompagné d'une référence au symptôme observé (commentaire, commit message,
ou issue). Cela garantit que la connaissance acquise lors du debug est préservée.

Après backport :
```
packer build → vm create (test) → tests automatisés → ✅ → commit
```

---

## 📊 Matrice de Décision Quantifiée

| Critère | Poids | Boucle naïve (rebuild) | Debug ad hoc sans méthode | **Cycle Observabilité-First** |
|---------|-------|------------------------|--------------------------|-------------------------------|
| **Efficacité (temps/itération)** | 35% | 🔴 2/10 | 🟡 5/10 | 🟢 9/10 |
| **Traçabilité du fix** | 25% | 🔴 3/10 | 🔴 2/10 | 🟢 9/10 |
| **Coût cloud** | 20% | 🔴 3/10 | 🟡 6/10 | 🟢 8/10 |
| **Fiabilité du diagnostic** | 20% | 🟡 5/10 | 🟡 5/10 | 🟢 9/10 |
| **Score Total Pondéré** | 100% | **3.20** | **4.25** | **8.85** ⭐ |

```
Boucle naïve  : (2*0.35) + (3*0.25) + (3*0.20) + (5*0.20) = 3.20
Ad hoc        : (5*0.35) + (2*0.25) + (6*0.20) + (5*0.20) = 4.25
Ce cycle      : (9*0.35) + (9*0.25) + (8*0.20) + (9*0.20) = 8.85 ✅
```

---

## ⚖️ Conséquences

### ✅ Positives (Bénéfices)

| Bénéfice | Description |
|----------|-------------|
| **Efficacité** | Le fix est confirmé avant le rebuild — une seule reconstruction suffit dans la majorité des cas |
| **Traçabilité** | La correspondance symptôme → provisioner est documentée, reproductible |
| **Réduction du coût cloud** | Moins de cycles packer build × déploiement VM |
| **Capitalisation** | Les bugs post-image et leurs corrections sont des actifs — ils améliorent la définition de l'image |
| **Cohérence avec ADR-614** | Complète naturellement le workflow d'itération rapide (phase pré-image) |

### ⚠️ Négatives (Risques & Limitations)

| Risque | Mitigation |
|--------|------------|
| La VM de debug peut diverger de l'état initial si les corrections s'accumulent | Utiliser une VM fraîche par session de debug, ou snapshotter avant toute modification |
| Le fix in-situ ne s'applique pas toujours (problème de boot, pas d'accès) | Recourir à la hiérarchie d'accès (Serial Console) ; en dernier recours seulement, hypothèse + rebuild |
| Oublier de backporter après validation | Lint/checklist dans le processus de PR : "le fix a-t-il été validé sur une VM ?" |

---

## 🔄 Alternatives Considérées

### Alternative 1 — Rebuild immédiat sur hypothèse

Modifier directement le provisioner sur la base des logs de build ou des messages
d'erreur, puis reconstruire l'image sans validation préalable sur une VM vivante.

**Rejetée** : coûteux en temps et en ressources cloud, ne garantit pas que le fix
est correct avant un nouveau cycle complet. Le taux d'itération moyen est de 3-5
cycles, soit 90-300 minutes de build inutile.

### Alternative 2 — Debug via logs uniquement (sans accès à la VM)

Analyser uniquement les logs disponibles (boot diagnostics, serial log,
journaux applicatifs exportés) sans jamais se connecter à la VM.

**Rejetée** : suffisant pour les problèmes de boot, mais inadéquat pour les bugs
applicatifs (configuration, intégration de services, comportement à l'exécution).
Les logs seuls ne permettent pas de valider un fix.

---

## 🔗 Relation avec les ADRs Connexes

| ADR | Relation |
|-----|----------|
| **ADR-613** | Définit l'architecture des provisioners et leur validation à la construction |
| **ADR-614** | Workflow d'itération rapide *avant* la construction de l'image (phase dev) |
| **ADR-617** | Packer comme outil de construction — la définition d'image cible du backport |
| **ADR-700** | Les tests automatisés constituent l'oracle de validation du fix (étapes 2 et 3) |

```
ADR-614 (pré-image, itération provisioner)
         ↓
ADR-617 (construction image avec Packer)
         ↓
ADR-618 (post-image, debug VM dérivée)  ← ce document
         ↓
ADR-700 (oracle de validation E2E)
```

---

## Références

- HashiCorp Packer — [Debugging Builds](https://developer.hashicorp.com/packer/docs/debugging)
- Azure — [Boot Diagnostics](https://learn.microsoft.com/en-us/azure/virtual-machines/boot-diagnostics)
- Azure — [Serial Console Linux](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-machines/linux/serial-console-linux)
- Azure CLI — `az vm run-command invoke` (Remote Command sans SSH)
