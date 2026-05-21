---
adr: 614
title: "Workflow de Développement VM Rapide"
status: "proposed"
date: 2026-04-16
superseded_by: null
replaces: null
related_adrs: [200, 613]
related_issues: []

classification:
  lifecycle: "proposed"
  domain: "devops"
  impact: "medium"
  quality:
    - "maintainability"
    - "reliability"
  reversibility: "easy"
  scope: "tactical"
  tech_areas:
    - "azure"
    - "packer"
    - "bash"

tags: ["vm", "dev-workflow", "iteration", "packer", "provisioner", "ssh", "debug"]
stakeholders: ["@devops-team", "@dev-team"]
effort: "medium"
---

# ADR-614: Workflow de Développement VM Rapide

**Statut**: Proposé  
**Date**: 2026-04-16  
**Auteur**: Copilot + Michel Héon  

## Contexte

Le cycle actuel de développement est trop lent:

```
packer-build (30-60 min) → déploie VM → corrige VM → corrige provisioners → packer-build...
```

Chaque itération prend 30-60 minutes minimum, ce qui rend le debug inefficace.

## Décision

Adopter un workflow à deux phases:

### Phase 1: Développement (itération rapide ~5 min)

```
vm-dev-create (5 min) → provision-push → debug SSH → fix → provision-push...
```

1. **vm-dev-create**: Crée une VM Ubuntu 22.04 vierge (même base que Packer)
2. **provision-push**: Pousse et exécute un provisioner spécifique sur la VM
3. **Debug via SSH**: Connexion directe pour diagnostiquer
4. **Répéter** jusqu'à ce que tous les provisioners fonctionnent

### Phase 2: Validation (une seule fois)

```
packer-build → vm-test-create → vm-test-verify → publication
```

1. **packer-build**: Construit l'image finale dans la gallery
2. **vm-test-create**: Déploie une VM depuis l'image gallery
3. **vm-test-verify**: Valide les 11 tests E2E
4. **Publication**: Si tout passe, prêt pour Marketplace

## Implémentation

### Structure des fichiers

```
packer/
├── dev/                          # NOUVEAU: Outils développement
│   ├── Makefile                  # Orchestration dev workflow
│   ├── scripts/
│   │   ├── vm-dev-create.sh      # Créer VM Ubuntu vierge
│   │   ├── vm-dev-destroy.sh     # Détruire VM dev
│   │   ├── vm-dev-ssh.sh         # Connexion SSH à VM dev
│   │   └── provision-push.sh     # Pousser/exécuter provisioner
│   └── .state/                   # État VM dev (ignoré par git)
├── e2e/                          # Tests E2E (existant)
└── provisioners/                 # Scripts provisioning (existant)
```

### Commandes Makefile (packer/dev/)

| Commande | Description | Durée |
|----------|-------------|-------|
| `make vm-dev-create` | Créer VM dev Ubuntu 22.04 | ~5 min |
| `make vm-dev-ssh` | Se connecter en SSH | instant |
| `make vm-dev-destroy` | Détruire VM dev | ~2 min |
| `make provision-push SCRIPT=01` | Exécuter provisioner 01 | variable |
| `make provision-push-all` | Exécuter tous les provisioners | ~20 min |
| `make vm-dev-snapshot` | Créer snapshot avant test | ~2 min |
| `make vm-dev-restore` | Restaurer snapshot | ~2 min |

### Workflow Typique

```bash
# 1. Créer VM de développement (une fois)
cd packer/dev
make vm-dev-create

# 2. Tester un provisioner spécifique
make provision-push SCRIPT=04    # 05-install-mediawiki.sh

# 3. Debug via SSH si erreur
make vm-dev-ssh
# ... debug manual ...
exit

# 4. Corriger le script localement
code ../provisioners/05-install-mediawiki.sh

# 5. Re-pousser pour valider
make provision-push SCRIPT=04

# 6. Une fois tout OK, nettoyer et builder l'image
make vm-dev-destroy
cd ..
make packer-build

# 7. Valider l'image finale
cd e2e
make vm-test-create
make vm-test-verify
make vm-test-destroy
```

## Avantages

| Aspect | Avant | Après |
|--------|-------|-------|
| Temps itération debug | 30-60 min | 2-5 min |
| Coût Azure/itération | ~$2-3 | ~$0.20 |
| Context switching | Perte totale | VM persistante |
| Debug interactif | Non | Oui (SSH) |

## Spécifications Techniques

### VM Dev Base Image

```bash
# Même image que Packer utilise
PUBLISHER="Canonical"
OFFER="0001-com-ubuntu-server-jammy"
SKU="22_04-lts-gen2"
```

### Configuration VM Dev

```bash
VM_SIZE="Standard_B2ms"      # 2 vCPU, 8 GB RAM (suffisant pour dev)
LOCATION="canadacentral"     # Même région que production
DISK_SIZE="30"               # GB (même que image)
```

### Transfert des provisioners

```bash
# provision-push.sh copie le script et l'exécute
scp ../provisioners/${SCRIPT}-*.sh devvm:/tmp/
ssh devvm "sudo -E bash /tmp/${SCRIPT}-*.sh"
```

## Risques et Mitigations

| Risque | Mitigation |
|--------|------------|
| VM dev diverge de Packer | Toujours valider avec packer-build final |
| Oublier les env vars | provision-push injecte les mêmes vars que Packer |
| Coût VM oubliée | Reminder + auto-shutdown après 4h |

## Checklist d'Implémentation

- [ ] Créer `packer/dev/Makefile`
- [ ] Créer `packer/dev/scripts/vm-dev-create.sh`
- [ ] Créer `packer/dev/scripts/vm-dev-destroy.sh`
- [ ] Créer `packer/dev/scripts/vm-dev-ssh.sh`
- [ ] Créer `packer/dev/scripts/provision-push.sh`
- [ ] Ajouter `packer/dev/.state/` à `.gitignore`
- [ ] Documenter dans README.md
- [ ] Tester le workflow complet

## Références

- ADR-100: Architecture Docker-first VM offer
- ADR-200: Infrastructure Azure
- ADR-601: Nomenclature scripts
- ADR-602: Makefile orchestrateur
