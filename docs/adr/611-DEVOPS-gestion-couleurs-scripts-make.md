---
adr: 611
title: "Gestion des Couleurs dans les Scripts Make"
status: "accepted"
date: 2026-04-10
superseded_by: null
replaces: null
related_adrs: [601, 602]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "low"
  quality:
    - "maintainability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "make"
    - "bash"

tags: ["makefile", "ansi", "colors", "terminal", "printf", "bash"]
stakeholders: ["@devops-team", "@dev-team"]
effort: "low"
---

# ADR-611 : Gestion des couleurs dans les scripts Make

## Vue d'Ensemble

**Problème** : Les séquences d'échappement ANSI (`\033[...`) pour les couleurs ne s'affichent pas correctement dans les Makefiles.

**Décision** : Utiliser `@printf` au lieu de `@echo` pour tous les messages colorés dans les Makefiles.

**Impact** : Amélioration de la lisibilité des outputs de build et diagnostic.

## Contexte

### Situation Initiale
Les Makefiles du projet utilisaient `@echo` pour afficher des messages avec des codes couleurs ANSI :

```makefile
# ❌ Ne fonctionne PAS - affiche le texte brut \033[0;32m
@echo "$(GREEN)✓ Success$(NC)"
```

Le résultat affiché était :
```
\033[0;32m✓ Success\033[0m
```

au lieu du texte coloré attendu.

### Cause Technique
La commande `echo` dans Make (via `/bin/sh`) n'interprète pas les séquences d'échappement ANSI par défaut. Le comportement de `echo` varie selon les shells :
- **dash** (défaut sur Ubuntu) : `echo` n'interprète pas `\033`
- **bash** : `echo -e` requis pour interpréter les séquences
- **zsh** : comportement variable

### Contraintes
- Portabilité entre différents shells et systèmes
- Compatibilité avec les environnements CI/CD
- Cohérence visuelle des outputs

## Décision

### Principe Adopté
**Utiliser `@printf` avec `\n` explicite pour tous les messages colorés.**

```makefile
# ✅ FONCTIONNE - printf interprète les séquences ANSI
@printf "$(GREEN)✓ Success$(NC)\n"
```

### Définition des Macros Couleurs

```makefile
# Couleurs ANSI
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
CYAN   := \033[0;36m
BOLD   := \033[1m
NC     := \033[0m

# Macros d'affichage standardisées
define log_action
	@printf "$(CYAN)➤ $(1)$(NC)\n"
endef

define log_success
	@printf "$(GREEN)✓ $(1)$(NC)\n"
endef

define log_warning
	@printf "$(YELLOW)⚠ $(1)$(NC)\n"
endef

define log_error
	@printf "$(RED)✗ $(1)$(NC)\n"
endef

define log_info
	@printf "$(BLUE)ℹ $(1)$(NC)\n"
endef
```

### Utilisation

```makefile
my-target:
	$(call log_action,Démarrage du processus...)
	@some-command
	$(call log_success,Processus terminé)
```

## Matrice de Décision

| Critère | @echo | @echo -e | @printf |
|---------|-------|----------|---------|
| Portabilité POSIX | ✓ | ✗ | ✓ |
| Interprète ANSI | ✗ | ✓ (bash) | ✓ |
| Standard POSIX | ✓ | ✗ | ✓ |
| CI/CD compatible | Variable | Variable | ✓ |

**Choix : `@printf`** - Standard POSIX, portable, interprète les séquences ANSI.

## Conséquences

### Positives
- **Affichage correct** : Les couleurs s'affichent sur tous les terminaux ANSI
- **Portabilité** : Fonctionne avec sh, bash, dash, zsh
- **Lisibilité** : Meilleure expérience développeur avec outputs colorés
- **CI/CD** : Logs colorés dans GitHub Actions, Azure DevOps

### Négatives
- **Syntaxe** : Nécessite `\n` explicite à la fin de chaque message
- **Migration** : Requiert de modifier les `@echo` existants

### Neutres
- Pas d'impact sur les performances
- Pas de dépendance externe ajoutée

## Implémentation

### Fichiers Concernés
- `packer/e2e/Makefile` - Makefile E2E tests (modifié)
- Tout futur Makefile du projet

### Règle de Style
```
RÈGLE: Dans les Makefiles, utiliser @printf pour tout message coloré.
       Ne jamais utiliser @echo avec des séquences \033.
```

## Références

- [POSIX printf](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/printf.html)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
- [GNU Make Manual](https://www.gnu.org/software/make/manual/)
- ADR-602 : Makefile comme orchestrateur

## Historique

| Date | Action | Auteur |
|------|--------|--------|
| 2025-06-13 | Création | Claude (AI) |
