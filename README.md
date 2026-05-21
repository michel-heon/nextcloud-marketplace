# nextcloud-marketplace

> Publication de Nextcloud sur Microsoft Azure Marketplace — VM Offer industrialisée, sécurisée et certifiée.

Ce projet vise à industrialiser et publier sur **Microsoft Azure Marketplace** une offre VM intégrant **Nextcloud Hub** sur Azure, avec PHP 8.2, Nginx et MariaDB, destinée aux organisations souhaitant déployer un stockage cloud enterprise sur leur abonnement Azure.

## Documentation

Toute la documentation architecturale (ADRs) se trouve dans [`docs/adr/`](docs/adr/README.md).

| Bloc | Plage | Description |
|------|-------|-------------|
| META | 000–099 | Processus, gouvernance, définition du projet |
| INFRA | 200–299 | Infrastructure Azure, VM Offer |
| SEC | 300–399 | Sécurité, hardening, SSO, RBAC |
| DEVOPS | 600–699 | Bootstrap, scripts, CI/CD, Packer |
| TEST | 700–799 | Plans et protocoles de tests |
| BIZ | 800–899 | Publication Azure Marketplace, documentation |

## Stack technique

- **Nextcloud Hub** 31.x
- **PHP** 8.2
- **Nginx** (reverse proxy + TLS)
- **MariaDB** 10.6+
- **Redis** ≤ 7.2
- **Azure VM** — Ubuntu 22.04 LTS
