# 🚀 Guide de Déploiement Automatisé

Ce guide documente le système de déploiement automatique entièrement configuré pour les microservices de l'architecture Mercurious.

## 📋 Vue d'ensemble

Le système de CI/CD automatisé comprend :
- **3 microservices** : api-gateway, api-enrichment, api-generation
- **Build automatique** via GitHub Actions
- **Déploiement automatique** via FluxCD + CronJob personnalisé
- **Communication** via Kafka inter-services

## 🏗️ Architecture du déploiement

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Push Code     │───▶│  GitHub Actions  │───▶│   GHCR Registry     │
│   (Developer)   │    │   Build & Push   │    │  (Docker Images)    │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                                           │
                                                           ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Kubernetes    │◀───│   Auto-Deploy   │◀───│   FluxCD Scanner    │
│   Deployments   │    │    CronJob       │    │  (Image Detection)  │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

## 🔧 Configuration des services

### Services déployés

| Service | URL | Type | Statut |
|---------|-----|------|--------|
| **api-gateway** | https://api2.gotravelyzer.com | Public (REST API) | ✅ Automatisé |
| **api-enrichment** | Interne uniquement | Privé (Kafka Consumer) | ✅ Automatisé |
| **api-generation** | Interne uniquement | Privé (Kafka Consumer) | ✅ Automatisé |

### Flux de communication

```
Internet ──HTTPS──▶ API Gateway ──Kafka──▶ Enrichment/Generation
                        ▲                           │
                        │                           │
                        └────────── Kafka ◀────────┘
```

## 🛠️ Configuration GitHub Actions

### Template `.github/workflows/publish.yml`

```yaml
name: Publish container

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-and-push:
    permissions:
      contents: read
      packages: write
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: |
            ghcr.io/team-mercurious/[SERVICE-NAME]:latest
            ghcr.io/team-mercurious/[SERVICE-NAME]:sha-${{ github.sha }}
```

**⚠️ Important :** Remplacez `[SERVICE-NAME]` par :
- `api-gateway` pour le repo api-gateway
- `api-enrichment` pour le repo api-enrichment  
- `api-generation` pour le repo api-generation

## 📦 Configuration FluxCD

### ImageRepository (exemple pour api-gateway)

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: api-gateway
  namespace: flux-system
spec:
  image: ghcr.io/team-mercurious/api-gateway
  interval: 1m0s
  secretRef:
    name: ghcr-secret
```

### ImagePolicy (exemple pour api-gateway)

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: api-gateway
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: api-gateway
  policy:
    alphabetical:
      order: desc
  filterTags:
    pattern: '^sha-[a-f0-9]+$'
    extract: '$0'
```

## ⚙️ CronJob de déploiement automatique

### Configuration

- **Fréquence** : Toutes les 2 minutes
- **Condition** : Déploie uniquement si nouvelle image détectée
- **Ressources** : 10m CPU, 32Mi RAM (très léger)
- **Politique** : Un seul job à la fois, historique limité

### Fonctionnement

1. Compare l'image actuelle du deployment vs l'image latest de l'ImagePolicy
2. Si différente → Patch le deployment avec la nouvelle image
3. Si identique → Aucune action (pas de logs inutiles)

### Script de déploiement

```bash
# Vérification manuelle
/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/auto-deploy.sh

# Forcer un redéploiement de tous les services
/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/force-deploy.sh
```

## 🔄 Workflow complet

### 1. Développement
```bash
# 1. Modifier le code
echo 'api-gateway-v2' > src/endpoint.js

# 2. Push vers GitHub
git add .
git commit -m "Update endpoint message"
git push origin main
```

### 2. Build automatique (GitHub Actions)
- Détection du push sur `main`
- Build de l'image Docker
- Push vers GHCR avec tags :
  - `latest`
  - `sha-{commit-hash}`

### 3. Détection automatique (FluxCD)
- Scan des registries **toutes les 1 minute**
- ImagePolicy sélectionne la dernière image SHA
- Statut mise à jour automatiquement

### 4. Déploiement automatique (CronJob)
- Vérification **toutes les 2 minutes**
- Comparaison image actuelle vs nouvelle
- Patch automatique si différence détectée
- Rolling update sans downtime

### 5. Vérification
```bash
# Vérifier le déploiement
kubectl get pods -n app

# Tester l'endpoint (pour api-gateway)
curl -k https://api2.gotravelyzer.com/

# Voir les logs du CronJob
kubectl logs -n app -l job-name --tail=10
```

## 🔍 Monitoring et troubleshooting

### Commandes utiles

```bash
# Statut des images
kubectl get imagerepository -n flux-system
kubectl get imagepolicy -n flux-system

# Statut des deployments
kubectl get deployments -n app

# Logs du CronJob auto-deploy
kubectl get cronjob -n app
kubectl logs -n app -l job-name --tail=20

# Forcer un scan manuel
kubectl annotate imagerepository api-gateway -n flux-system \
  image.toolkit.fluxcd.io/reconcile=$(date +%s)
```

### Diagnostic des problèmes

#### ImageRepository en erreur
```bash
kubectl describe imagerepository [SERVICE] -n flux-system
```
**Solutions communes :**
- Vérifier que `secretRef.name: ghcr-secret` est présent
- Vérifier les permissions GHCR
- Vérifier que l'image existe dans le registry

#### Déploiement non automatique
```bash
kubectl logs -n app -l job-name --tail=10
```
**Solutions :**
- Exécuter manuellement : `/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/auto-deploy.sh`
- Vérifier que l'ImagePolicy détecte la bonne image
- Vérifier les permissions du ServiceAccount

#### Pods en erreur après déploiement
```bash
kubectl logs -n app [POD-NAME] --tail=50
kubectl describe pod -n app [POD-NAME]
```

## 📊 Performance et optimisation

### Ressources utilisées
- **CronJob** : 10m CPU, 32Mi RAM par exécution (2-3 secondes)
- **Impact minimal** : Vérifications légères toutes les 2 minutes
- **Logs optimisés** : Uniquement si changements détectés

### Bonnes pratiques
- ✅ Tags SHA pour traçabilité parfaite
- ✅ Rolling updates sans downtime
- ✅ Monitoring automatique des échecs
- ✅ Rollback possible via Kubernetes
- ✅ Sécurité : Services internes non exposés

## 🚨 Sécurité

### Services exposition
- **api-gateway** : Exposé via HTTPS (Ingress + Let's Encrypt)
- **api-enrichment** : Interne uniquement (pas d'ingress)
- **api-generation** : Interne uniquement (pas d'ingress)

### Communication
- **Inter-services** : Via Kafka (chiffré SASL)
- **Database** : MongoDB avec authentification
- **Cache** : Redis avec authentification

### Secrets gestion
- GitHub Container Registry : `ghcr-secret`
- Kafka : `kafka-sasl` 
- Database/APIs : `app-common-secrets`

## 🎯 Temps de déploiement

| Étape | Durée | Cumulé |
|-------|-------|---------|
| Push code | Instantané | 0s |
| GitHub Actions | ~2-3 minutes | 3min |
| FluxCD scan | ~1 minute | 4min |
| CronJob deploy | ~2 minutes max | 6min |
| **Total** | **~6 minutes** | **6min** |

## ✅ Checklist de vérification

Après un déploiement :

- [ ] Nouveau tag SHA visible dans GHCR
- [ ] ImageRepository détecte le tag (`kubectl get imagerepository -n flux-system`)
- [ ] ImagePolicy sélectionne la bonne image (`kubectl get imagepolicy -n flux-system`)
- [ ] Pods redéployés avec nouvelle image (`kubectl get pods -n app`)
- [ ] Services fonctionnels (test des endpoints)
- [ ] Logs sans erreur (`kubectl logs -n app -l job-name --tail=10`)

## 📞 Support

En cas de problème :
1. Consulter les logs avec les commandes ci-dessus
2. Vérifier les statuts FluxCD
3. Exécuter manuellement le script de déploiement
4. Consulter la section troubleshooting

**Système opérationnel depuis le 11/08/2025** ✅