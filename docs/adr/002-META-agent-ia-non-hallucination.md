---
adr: 2
title: "Agent IA — Contrainte de Non-Hallucination et Usage Vérifié"
status: "accepted"
date: 2026-05-09
superseded_by: null
replaces: null
related_adrs: [0, 1]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "meta"
  impact: "high"
  quality:
    - "reliability"
    - "maintainability"
    - "compliance"
    - "traceability"
  reversibility: "easy"
  scope: "strategic"
  tech_areas:
    - "ai"
    - "tooling"
    - "documentation"

tags: ["ia", "agent", "hallucination", "gouvernance", "fiabilité", "vérification"]
stakeholders: ["@architecture-team", "@devops-team", "@dev-team"]
effort: "low"
---

# ADR-002 : Agent IA — Contrainte de Non-Hallucination et Usage Vérifié

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-05-09 |
| **Stakeholders** | @architecture-team, @devops-team, @dev-team |
| **Impact** | 🔴 Élevé |
| **Effort Implémentation** | 🟢 Faible |
| **Risque Technique** | 🟡 Moyen |

---

## 🎯 Contexte & Problème

Les agents IA (GitHub Copilot, Claude, GPT, etc.) sont utilisés activement dans ce projet pour
générer du code, des scripts d'infrastructure, des templates Packer, des ADRs et de la
documentation technique.

Ces outils peuvent **halluciner** — produire des informations factuellement fausses avec une
apparente confiance : numéros de versions inventés, URLs inexistantes, paramètres d'API
incorrects, commandes CLI erronées, extraits de configuration invalides.

Dans le contexte d'un projet publié sur **Azure Marketplace**, une hallucination non détectée
peut avoir des conséquences directes :
- Échec de certification Microsoft (test de conformité automatisé)
- Faille de sécurité inscrite dans une image VM immuable
- Documentation utilisateur erronée impossible à corriger sans republication
- Temps de débogage disproportionné sur des artefacts générés sans base vérifiable

**Besoin central** : établir une règle de projet claire encadrant l'usage des agents IA,
afin que toute contribution générée par IA soit vérifiable, sourcée, et auditée avant intégration.

---

## 💡 Décision

**Tout contenu généré par un agent IA et intégré dans ce dépôt doit reposer sur des faits
vérifiés à partir de sources primaires officielles.** L'agent IA ne peut pas affirmer ou
documenter une information technique sans être en mesure de la sourcer.

### Règles opérationnelles

#### 1. Sourçage obligatoire pour les informations techniques

Toute information technique produite par l'IA doit être fondée sur au moins une source
primaire officielle consultée pendant la session :

| Type d'information | Source primaire acceptable |
|--------------------|---------------------------|
| Versions de logiciels (PHP, Nextcloud, MariaDB…) | Site officiel du projet, releases GitHub |
| Documentation Nextcloud (occ, config.php, apps) | `nextcloud.com`, `docs.nextcloud.com`, `github.com/nextcloud/server` |
| Paramètres de configuration Packer/Azure | `developer.hashicorp.com`, `learn.microsoft.com` |
| Commandes CLI (`az`, `packer`, `waagent`…) | Documentation officielle de l'outil |
| Exigences Azure Marketplace | `learn.microsoft.com/azure/marketplace` |
| Comportement de packages système Ubuntu | `manpages.ubuntu.com`, documentation Canonical |

#### 2. Interdiction d'inventer des références

L'agent IA **ne doit pas** :
- Citer une URL sans l'avoir consultée (ou sans pouvoir la vérifier)
- Affirmer un numéro de version sans le sourcer
- Proposer un paramètre de configuration en supposant son existence
- Générer un lien vers un ADR, une issue, ou un fichier qui n'existe pas encore

#### 3. Signal explicite en cas d'incertitude

Quand l'agent IA ne peut pas vérifier une information, il doit le signaler explicitement :

```
⚠️ Non vérifié : cette information n'a pas été confirmée depuis une source primaire.
Vérifier avant intégration : <URL ou commande de vérification>
```

#### 4. Validation humaine obligatoire avant commit

Toute contribution générée par IA passe par une relecture humaine avant `git commit`.
La relecture porte notamment sur :
- La cohérence des numéros de versions avec l'état réel du projet
- La validité des URLs et références croisées entre ADRs
- La conformité du code/config avec la documentation officielle citée

#### 5. Périmètre de cette règle

Cette règle s'applique à **tous les artefacts** : code bash, templates HCL2 Packer,
ADRs, documentation Markdown, fichiers de configuration, variables d'environnement.

---

## ⚖️ Alternatives Évaluées

### 1. Confiance implicite dans l'agent IA

Utiliser le contenu généré tel quel, sans vérification systématique.

**Rejeté** : les modèles LLM produisent régulièrement des hallucinations confiantes sur des
sujets techniques spécifiques (versions, APIs, configuration). Le risque est inacceptable
pour un artefact publié sur Azure Marketplace.

### 2. Bannir les agents IA du projet

N'utiliser aucun outil IA dans la chaîne de production du projet.

**Rejeté** : les agents IA apportent une productivité réelle et mesurable pour la
génération d'ADRs, la rédaction de scripts, la détection d'incohérences. Les bannir est
disproportionné ; les encadrer est suffisant.

### 3. Revue systématique par un second humain (four-eyes)

Tout contenu IA reviewé par deux personnes avant intégration.

**Non retenu à ce stade** : l'équipe est réduite ; la règle de sourçage obligatoire
(décision retenue) est un contrôle équivalent applicable immédiatement.

---

## ✅ Conséquences

### Positives

- **Fiabilité** : les artefacts intégrés sont fondés sur des faits vérifiables, pas sur
  des interpolations probabilistes du modèle
- **Traçabilité** : chaque information technique est associée à une source consultable,
  ce qui facilite les mises à jour futures (ex : montée de version PHP, nouveau plugin Packer)
- **Confiance dans la documentation** : les ADRs et la doc Marketplace peuvent être cités
  avec assurance dans les échanges avec Microsoft Partner Center
- **Détection d'erreurs** : le processus de vérification révèle aussi les incohérences
  dans les sources elles-mêmes (versions conflictuelles, docs obsolètes)

### Contraintes à gérer

- **Ralentissement ponctuel** : vérifier chaque information depuis une source primaire
  allonge le temps de génération d'un ADR ou d'un script (acceptable)
- **L'IA peut ne pas avoir accès à internet** : dans ce cas, l'agent doit signaler
  explicitement qu'il travaille depuis sa connaissance interne d'entraînement, dont la
  date de coupure est connue et documentée
- **Connaissance d'entraînement ≠ hallucination** : si l'agent cite sa connaissance
  d'entraînement en le signalant clairement, c'est conforme à cette règle — l'interdiction
  porte sur l'affirmation non sourcée présentée comme certaine

---

## 📏 Critères de Succès

| Critère | Mesure |
|---------|--------|
| Zéro URL cassée dans les ADRs | Vérification périodique par `wget --spider` ou équivalent |
| Zéro version inventée dans la documentation | Versions croisées avec releases GitHub officielles |
| Signalement explicite lors de chaque incertitude | Observable dans les réponses de l'agent en session |
| Aucun commit IA non reviewé | Garanti par convention Git (voir ADR-603) |

---

## 🔗 Références

| Ressource | URL |
|-----------|-----|
| ADR-000 — Processus de création des ADRs | [./000-META-processus-creation-adr.md](./000-META-processus-creation-adr.md) |
| ADR-001 — Définition du projet nextcloud-marketplace | [./001-META-definition-projet-nextcloud-marketplace.md](./001-META-definition-projet-nextcloud-marketplace.md) |
| ADR-603 — Git workflow et stratégie de versioning | [./603-DEVOPS-git-workflow-et-strategie-versioning.md](./603-DEVOPS-git-workflow-et-strategie-versioning.md) |
| Anthropic — Limitations connues des LLMs | <https://www.anthropic.com/research> |
| "Hallucination in Large Language Models" (survey) | Littérature académique — Zhang et al., 2023 |
