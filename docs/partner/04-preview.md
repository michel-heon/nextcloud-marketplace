# Étape 4 — Preview Audience

> Partner Center : Offer → **Preview audience**

Configurer les Azure Subscription IDs autorisés à voir et déployer l'offre
**avant** qu'elle soit publiée live sur Azure Marketplace.

---

## Subscriptions à ajouter

| Subscription | Usage |
|-------------|-------|
| Subscription dev Cotechnoe | Validation end-to-end avant Go Live |

```
# Récupérer l'ID de la subscription active
az account show --query id -o tsv
```

---

## Checklist de validation en preview

Avant de cliquer **Go Live**, vérifier manuellement depuis la preview :

- [ ] Déployer la VM depuis le Marketplace preview (bouton "Deploy")
- [ ] Vérifier que le déploiement ARM se complète sans erreur
- [ ] SSH sur la VM créée
- [ ] Lancer `sudo /opt/cotechnoe/setup.sh` (post-deployment wizard)
- [ ] `curl -sk https://localhost/status.php | jq .installed` → `true`
- [ ] Redirect HTTP → HTTPS fonctionnel (`curl -I http://localhost/` → 301)
- [ ] `make vm-smoke-test` depuis la machine locale

---

## Note

La preview audience doit être configurée **avant** de soumettre pour review.
Sans au moins un Subscription ID, la soumission est bloquée.
