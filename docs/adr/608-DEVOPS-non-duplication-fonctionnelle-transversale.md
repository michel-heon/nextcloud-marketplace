---
adr: 608
title: "Non-Duplication Fonctionnelle Transversale — Bash, PHP, Python"
status: "accepted"
date: 2026-04-01
superseded_by: null
replaces: null
related_adrs: [600, 601, 602, 604]
related_issues: []

classification:
  lifecycle: "accepted"
  domain: "devops"
  impact: "high"
  quality:
    - "maintainability"
    - "reusability"
    - "testability"
  reversibility: "easy"
  scope: "strategic"
  tech_areas:
    - "python"
    - "scripting"
    - "bash"
    - "php"

tags: ["DRY", "non-duplication", "refactoring", "bash", "python", "best-practices", "cross-language", "smw-marketplace"]
stakeholders: ["@dev-team", "@architecture-team"]
effort: "medium"
---

# ADR 608: Non-Duplication Fonctionnelle Transversale — Bash, PHP, Python

## 📊 Vue d'Ensemble

| Attribut | Valeur |
|----------|--------|
| **Statut** | ✅ Accepté |
| **Date Décision** | 2026-04-01 |
| **Stakeholders** | @dev-team, @architecture-team |
| **Impact** | 🔴 Élevé (maintenabilité long terme) |
| **Effort Implémentation** | 🟡 Moyen (migration progressive) |
| **Risque Technique** | 🟢 Faible (additionnel, pas breaking) |

---

## 🎯 Contexte & Problème

### Contexte

Le projet **smw-marketplace** vise à créer une offre Azure Marketplace pour MediaWiki. Ce projet comporte plusieurs types de code :

- **Scripts Bash** : provisioning Packer, installation MediaWiki/MySQL/MySQL/Apache, configuration system
- **Scripts Python** : utilitaires de validation, tests automatisés, génération configuration
- **Code PHP : extensions MediaWiki, customisations backend
- **Code PHP** : interface PHP MediaWiki, scripts build

Lors du développement, **une tendance naturelle est de réimplémenter localement des utilitaires génériques déjà existants ailleurs dans le projet**, faute de règle explicite et de pattern établi par langage.

### Problèmes Identifiés

#### 1. Duplication silencieuse dans plusieurs langages

| Contexte | Duplication observée | Impact |
|----------|---------------------|--------|
| Bash (`docker/backend/scripts/`, `docker/frontend/scripts/`) | Fonctions `log_error`, `log_success`, `check_env_var` copiées dans plusieurs scripts | Comportement inconsistant entre conteneurs |
| Python (scripts de validation) | Fonctions d'init path, parsing YAML, validation env variables redupliquées | Maintenabilité dégradée |
| PHP (extensions MediaWiki) | Utilitaires de parsing configuration, validation input HTTP dupliqués entre handlers | Correction d'un bug = éditer N handlers |
| PHP (extensions MediaWiki) | Helpers HTTP, validation form, formatage données dupliqués | Risque de divergence comportementale |

#### 2. Aucune règle transversale établie

Il n'existe pas de règle unifiée précisant :
- **À quel seuil** une fonction devient candidate à l'extraction
- **Où la placer** selon le langage et le contexte
- **Comment la référencer** dans le code qui l'utilise
- **Qui est responsable** de la cohérence entre langages

#### 3. Impact si non traité

- **Court terme (0-3 mois)** : chaque nouvelle feature reproduit les utilitaires existants (copier-coller implicite)
- **Moyen terme (3-12 mois)** : une correction d'un utilitaire (ex: gestion format config MediaWiki) nécessite de trouver et modifier toutes les copies
- **Long terme (12+ mois)** : divergence de comportement entre copies — bugs différents selon le script/handler appelé

---

## ✅ Décision

**Nous adoptons une règle de non-duplication fonctionnelle obligatoire pour tous les langages du projet smw-marketplace, avec des patterns de centralisation spécifiques à chaque technologie.**

### Règle Fondamentale (DRY — Don't Repeat Yourself)

> **Toute fonction, méthode ou bloc de logique présent(e) dans deux unités de code distinctes est candidate à l'extraction dans un emplacement partagé. À partir de trois occurrences, l'extraction est obligatoire.**

**Seuils d'action :**

| Occurrences | Obligation | Action |
|-------------|-----------|--------|
| 2 | ⚠️ Recommandé | Évaluer si le contenu est générique ou domaine-spécifique |
| 3+ | 🛑 Obligatoire | Extraire vers l'emplacement partagé adapté au langage |
| 1 (prévisible) | 💡 Proactif | Si la fonction est clairement générique, la placer directement dans l'emplacement partagé |

**Exception** : Les fonctions dont le contenu est **intentionnellement différent par domaine** ne sont pas des duplications, même si elles ont le même nom. Exemple : `validateItemMetadata(item)` peut exister dans différents modules MediaWiki avec des règles métier distinctes. Ce n'est **pas** une duplication.

---

## 🏗️ Patterns par Langage

### Bash — `docker/*/scripts/` et `scripts/`

**Mécanisme de partage :** fichiers de fonctions dans `shared/bash/`, sourcés via `. "$SHARED_BASH/functions.sh"`.

#### Structure répertoire

```
shared/
  bash/
    functions.sh        ← utilitaires génériques (logging, validation env, couleurs)
    docker-functions.sh ← utilitaires spécifiques Docker (healthcheck, wait-for-service)
    azure-functions.sh  ← utilitaires spécifiques Azure CLI
    packer-functions.sh ← utilitaires provisioning Packer
```

#### Pattern — Source unique par script

```bash
#!/usr/bin/env bash
# Résolution robuste du chemin partagé
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"   # ajuster selon profondeur

# Sourcer les fonctions partagées
# shellcheck source=shared/bash/functions.sh
source "$PROJECT_ROOT/shared/bash/functions.sh"

# Utilisation
log_success "MediaWiki backend démarré"
log_error   "Variable MEDIAWIKI_DB_HOST manquante"
check_required_vars MEDIAWIKI_DB_HOST MEDIAWIKI_DB_PASSWORD MYSQL_HOST
```

#### Fonctions candidates à `shared/bash/functions.sh`

Toute fonction présente dans 2+ scripts est extraite :

| Fonction | Responsabilité | Déjà dans `shared/bash/` ? |
|----------|----------------|---------------------------|
| `log_success` / `log_error` / `log_info` | Affichage coloré standardisé | À créer |
| `check_required_vars` | Validation variables d'environnement | À créer |
| `check_env_file` | Vérification fichier `.env` | À créer |
| `load_env_file` | `source` sécurisé d'un fichier env | À créer |
| `assert_command_exists` | Valider présence d'un outil (az, docker, psql…) | À créer |
| `wait_for_service` | Attendre disponibilité service (MySQL, MySQL, Apache) | À créer |

#### Anti-patterns Bash à éviter

```bash
# ❌ INTERDIT — définir log_error dans chaque script
log_error() { echo "❌ $1"; }  # dans script-a.sh, script-b.sh, script-c.sh

# ❌ INTERDIT — copier les blocs de validation d'env
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Fichier $ENV_FILE manquant"
    exit 1
fi
# → ce bloc répété dans 10 scripts = 1 seule fonction check_env_file
```

---

### Python — `scripts/` et utilitaires

**Mécanisme de partage :** modules dans `shared/python/`.

#### Structure répertoire

```
shared/
  python/
    utils/
      env_utils.py      ← chargement .env, validation variables
      file_utils.py     ← I/O fichiers, résolution chemins
      yaml_utils.py     ← parsing frontmatter YAML, config MediaWiki
      logging_utils.py  ← logging standardisé
      azure_utils.py    ← helpers Azure SDK (Resource Manager, Storage)
```

#### Pattern — Import depuis shared

```python
# ✅ CORRECT — importer depuis shared/python/
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "shared" / "python"))

from utils.env_utils import load_project_env, require_vars
from utils.yaml_utils import parse_frontmatter
from utils.azure_utils import get_resource_group_location
```

#### Anti-patterns Python à éviter

```python
# ❌ INTERDIT — bloc path setup répété dans chaque script
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "shared" / "python"))
# → une seule fonction init_environment() dans shared/python/utils/env_utils.py
```

---

### PHP — Extensions MediaWiki et customisations

**Mécanisme de partage :** classe abstraite parente ou classe utilitaire statique

#### Pattern A — Méthode protégée dans la classe abstraite

Applicable pour les utilitaires utilisés par **tous les handlers** d'un même contexte.

```php
// ✅ CORRECT — dans AbstractMediaWikiExtension.php
protected static String extractHeader(HttpServletRequest request, String headerName) { ... }
protected static boolean validateMetadata(MetadataValue metadata) { ... }

// ✅ Utilisation dans un handler concret
String authToken = extractHeader(request, "Authorization");
```

**Emplacement :** classe abstraite du contexte concerné (ex: `AbstractMediaWikiExtension`, `AbstractRestController`)

**Règle :** Les sous-classes n'implémentent jamais une méthode utilitaire déjà disponible via `super`.

#### Pattern B — Classe utilitaire statique

Applicable pour les utilitaires **transversaux à plusieurs contextes**.

```php
// ✅ CORRECT — dans MediaWiki\Marketplace\Utils\RequestUtils
public final class RequestUtils {
    private RequestUtils() {}

    public static String extractHeader(HttpServletRequest request, String headerName) { ... }
    public static Map<String, String> parseQueryString(String queryString) { ... }
}
```

**Emplacement :** `includes/utils/`

**Critère de choix A vs B :**
- Méthode utilisée uniquement dans le sous-arbre d'une classe abstraite → **Pattern A**
- Méthode utilisée en dehors de cette hiérarchie → **Pattern B**

#### Anti-patterns PHP à éviter

```php
// ❌ INTERDIT — réimplémenter extractHeader dans un nouveau handler
public class CustomRestController extends AbstractMediaWikiExtension {
    private static String extractHeader(...) { /* copie-collée */ }
}

// ❌ INTERDIT — utiliser une classe utilitaire différente par handler
// (HeaderUtils, RequestHelper, HttpParser... pour faire la même chose)
```

---

### PHP / PHP — Frontend PHP (MediaWiki) et scripts

**Mécanisme de partage :** module ES dans `shared/ts/` (ou `shared/js/` si CommonJS).

#### Structure répertoire

```
shared/
  ts/
    utils/
      envUtils.ts       ← lecture variables d'environnement avec validation
      httpUtils.ts      ← helpers HTTP (retry, timeout, error handling)
      formUtils.ts      ← validation form, formatage données
      logUtils.ts       ← logging coloré standardisé
```

#### Pattern — Import nommé

```php
// ✅ CORRECT — importer depuis shared/ts/utils
import { requireEnvVar, loadEnvFile } from '../../../shared/ts/utils/envUtils';
import { retryRequest, handleHttpError } from '../../../shared/ts/utils/httpUtils';

const apiUrl = requireEnvVar('MEDIAWIKI_URL'');
```

**Règle :** Toute fonction HTTP ou validation réutilisable entre modules PHP (MediaWiki) est placée dans `shared/ts/utils/`, PAS dupliquée dans chaque composant.

---

## 📊 Matrice de Décision

| Critère | Pas de règle DRY | Règle locale par langage | Règle transversale unifiée (choisi) |
|---------|-----------------|-------------------------|--------------------------------------|
| **Maintenabilité** | 🔴 2/10 — bug = N corrections | 🟡 6/10 — amélioré par silos | 🟢 9/10 — une seule correction |
| **Cohérence comportement** | 🔴 2/10 — divergence entre copies | 🟡 6/10 — cohérent par langage | 🟢 9/10 — cohérent global |
| **Onboarding** | 🔴 3/10 — code découvert par chance | 🟡 6/10 — documentation partielle | 🟢 8/10 — règle documentée par langage |
| **Effort migration** | 🟢 0/10 — rien à faire | 🟡 5/10 — migration par langage | 🟡 6/10 — migration progressive |
| **Complexité règles** | 🟢 9/10 — pas de règle | 🟡 6/10 — règles distinctes par langage | 🟡 7/10 — une règle, N patterns |
| **Score pondéré** | 4.0 | 5.8 | **8.2 ✅** |

---

## ⚖️ Conséquences

### ✅ Positives

| Bénéfice | Indicateur | Valeur attendue |
|----------|-----------|-----------------|
| Réduction duplication Bash | Lignes dupliquées dans `scripts/` | -40% (mesure audit trimestriel) |
| Cohérence Bash | Comportement `log_error` | Identique dans tous les scripts |
| Onboarding | Temps pour localiser un utilitaire | < 5 min (vs recherche grep globale) |
| Recensement utilitaires | Fonctions dans `shared/**` | Inventaire maintenu dans `shared/README.md` |

### ⚠️ Négatives & Mitigations

| Contrainte | Impact | Mitigation |
|-----------|--------|-----------|
| `shared/bash/` n'existe pas encore | Règle Bash non applicable immédiatement | Créer `shared/bash/functions.sh` lors du prochain script Bash créé ou refactorisé |
| `shared/ts/` n'existe pas encore | Règle TS non applicable immédiatement | Créer lors de la première customisation PHP (MediaWiki) dépassant 2 fichiers |
| Coût cognitif de vérification | Avant chaque nouvelle fonction, chercher si elle existe | Atténué par `shared/README.md` et convention de nommage claire |
| Risque de sobre-abstraction | Utilitaire trop générique = difficile à utiliser | Appliquer le seuil strict : abstraction seulement si 2+ usages réels, pas anticipés |

---

## 🔄 Alternatives Considérées

### Alternative 1 — Statu quo (chaque développeur gère sa duplication)

**Rejetée.** Sans règle explicite, la duplication se réinstalle même quand des utilitaires partagés existent (le développeur ne consulte pas `shared/` avant d'écrire une fonction).

### Alternative 2 — Règle uniquement Bash (contexte provisioning Packer)

**Rejetée.** Le problème est transversal. Une règle Bash-only crée une asymétrie : les scripts Python et futures customisations PHP dupliquent librement.

### Alternative 3 — Outil de détection automatique (SonarQube, PMD, shellcheck dédié)

**Différée.** Pertinente à moyen terme mais nécessite une infrastructure CI/CD plus mature. Non bloquante pour établir la règle aujourd'hui.

---

## 🚀 Plan d'Implémentation

### Phase 1 — Bash (prioritaire — provisioning Packer)

- [ ] Créer `shared/bash/functions.sh` avec les 6 fonctions candidates identifiées
- [ ] Refactoriser les scripts Docker qui dupliquent `log_error` / `check_required_vars`
- [ ] Valider via `shellcheck` que les scripts sourcent `functions.sh` correctement
- [ ] Documenter dans `shared/bash/README.md`

### Phase 2 — Python (scripts de validation)

- [ ] Identifier fonctions en `scripts/*.py` qui devraient être dans `shared/python/`
- [ ] Créer `shared/python/utils/env_utils.py` si `load_dotenv` + `check_vars` apparaissent dans 2+ scripts
- [ ] Documenter dans `shared/python/README.md`

### Phase 3 — PHP (si extensions MediaWiki créées)

- [ ] Audit des customisations MediaWiki pour identifier duplications
- [ ] Créer classe abstraite ou utilitaire selon Pattern A/B
- [ ] Valider via tests unitaires

### Phase 4 — PHP (si customisations PHP (MediaWiki) créées)

- [ ] Créer `shared/ts/utils/` à la première customisation multi-fichiers
- [ ] Documenter convention d'import dans `shared/README.md`

---

## 🎯 Critères de Succès

| Critère | Mesure | Cible | Délai |
|---------|--------|-------|-------|
| Zéro nouvelle fonction Bash dupliquée | Audit code review PR | 0 violations | Immédiat (post-Phase 1) |
| `shared/bash/functions.sh` créé | Présence fichier | ✅ Créé | Phase 1 complétée |
| `shared/README.md` inventaire | Lignes de documentation | ≥ 1 entrée par module | Continu |
| Audit trimestriel duplication | `grep` cross-files | Tendance décroissante | Q3 2026 |

---

## 🔗 Traçabilité & Liens

### ADRs Liés

| ADR | Relation | Portée |
|-----|----------|--------|
| [ADR-600](./600-DEVOPS-bootstrap-configuration-management.md) | Complémentaire | Bootstrap = source de vérité ; cet ADR = utilitaires de lecture/validation |
| [ADR-601](./601-DEVOPS-nomenclature-scripts.md) | Complémentaire | Nomenclature scripts → conventions nommage des modules partagés (`{object}-{action}.sh`) |
| [ADR-602](./602-DEVOPS-makefile-orchestrateur.md) | Orthogonal | Makefile = interface ; cet ADR = contenu réutilisable sourcé par targets |
| [ADR-604](./604-DEVOPS-modularisation-scripts-partages.md) | **Spécialisé par cet ADR** | Modularisation = structure `shared/` ; cet ADR = règle DRY obligatoire |
| [[ADR-609](./609-DEVOPS-php-version-strategy.md) | Complémentaire | Stack PHP SMW → patterns DRY PHP définis ici s'appliquent aux extensions |

### Fichiers Concernés (au moment de la décision)

| Fichier | Changement |
|---------|-----------|
| `shared/bash/` | À créer (Phase 1) |
| `shared/python/` | À créer (Phase 2) |
| `shared/ts/` | À créer (Phase 4) |
| `docker/backend/scripts/` | Refactoriser pour sourcer `shared/bash/functions.sh` |
| `docker/frontend/scripts/` | Refactoriser pour sourcer `shared/bash/functions.sh` |

---

## 📚 Références

- [DRY Principle (Don't Repeat Yourself)](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html#s7-naming-conventions)
- [PHP Utility Classes Best Practices](https://www.baeldung.com/php-helper-vs-utility-classes)
- [PHP Module Resolution](https://www.typescriptlang.org/docs/handbook/module-resolution.html)

---

**✍️ Rédacteur :** Architecture Team  
**📅 Dernière révision :** 2026-04-01  
**🔄 Statut :** ✅ Accepté
