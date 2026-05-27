# Étape 6 — Technical Configuration

> Partner Center : Plans → standard → **Technical configuration**

---

## Source de l'image

Choisir **Azure Compute Gallery** (recommandé par Microsoft pour les VM Marketplace).

> ⚠️ **Prérequis** : L'image definition doit avoir `SecurityType = TrustedLaunch`.
> Une definition en `TrustedLaunchSupported` est **silencieusement absente** du dropdown.
> Voir [ADR-800 § SecurityType](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md).

---

## Valeurs du formulaire

| Champ | Valeur |
|-------|--------|
| **Image source** | Azure Compute Gallery |
| **Subscription** | ID de la subscription `rg-nc-marketplace` |
| **Gallery** | `galNCMarketplace` |
| **Image definition** | `nextcloud-server` |
| **Image version** | `6.0.20260517` (ou la version courante) |
| **Nextcloud version déployée dans ce plan** | `33.0.3` |
| **VM generation** | Gen 2 (Hyper-V V2) |
| **OS type** | Linux |
| **Security type** | Trusted launch |

---

## VM properties

| Propriété | Valeur |
|-----------|--------|
| **Recommended VM sizes** | Standard_D2s_v3 (minimum), Standard_D4s_v3 (recommandée) |
| **Open ports** | 443 (HTTPS), 22 (SSH) |
| **Disk controller** | SCSI |

---

## Généralisation

> L'image doit être **généralisée** (`waagent -deprovision+user -force`).
> Cette étape est effectuée par `packer/provisioners/08-cleanup-generalize.sh`.
> Voir [ADR-800 § Généralisation](../adr/800-BIZ-publication-azure-marketplace-vm-offer.md).

---

## Vérification pré-soumission

```bash
# Vérifier SecurityType de l'image definition
az sig image-definition list \
  --resource-group rg-nc-marketplace \
  --gallery-name galNCMarketplace \
  --query "[].{Name:name, SecurityType:features[?name=='SecurityType'].value|[0], HyperVGen:hyperVGeneration, State:provisioningState}" \
  -o table
# Attendu : nextcloud-server | TrustedLaunch | V2 | Succeeded

# Vérifier les permissions Partner Center sur la gallery
GALLERY_ID=$(az sig show \
  --resource-group rg-nc-marketplace \
  --gallery-name galNCMarketplace \
  --query id -o tsv)
az role assignment list --scope "$GALLERY_ID" \
  --query "[?contains(roleDefinitionId,'cf7c76d2')].{SP:principalId,Role:roleDefinitionName}" \
  -o table
# Attendu : 2 lignes "Compute Gallery Image Reader"
```

Si les permissions manquent :
```bash
make marketplace-gallery-permissions
```

---

## Historique des versions soumises

| Version | Date build | Statut |
|---------|-----------|--------|
| `6.0.20260517` | 2026-05-17 | En cours de soumission |
