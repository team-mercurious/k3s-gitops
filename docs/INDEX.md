# 📚 Documentation Infrastructure Mercurious

Documentation complète de l'infrastructure Kubernetes et du système de déploiement automatisé.

## 📊 Vue d'ensemble

**Infrastructure** : 1 VPS Ubuntu 22.04 (37.59.98.241)  
**Applications** : 3 microservices avec déploiement automatisé ✅  
**Domaine** : gotravelyzer.com  
**Repository GitOps** : https://github.com/team-mercurious/k3s-gitops

## 🏗️ Architecture

| Document | Description |
|----------|-------------|
| [Vue d'ensemble](./architecture/overview.md) | Architecture générale, diagrammes, principes |
| [Composants](./architecture/components.md) | Détail technique de chaque composant |
| [**Configuration Kafka**](./architecture/kafka-configuration.md) | Configuration Kafka, SASL, topics et consumers ⭐ |

**Points clés :**
- K3s single-node avec Traefik intégré
- FluxCD pour GitOps avec automation d'images  
- Kafka pour communication inter-microservices
- Déploiement 100% automatisé via CronJob
- SSL automatique avec Let's Encrypt

## 🛠️ Outils déployés

| Outil | Version | Namespace | Description | Doc |
|-------|---------|-----------|-------------|-----|
| **K3s** | v1.33.3+k3s1 | - | Orchestrateur Kubernetes | [📖](./tools/k3s.md) |
| **Traefik** | Bundled | kube-system | Reverse proxy / Ingress | [📖](./tools/traefik.md) |
| **FluxCD** | 2.6.4 | flux-system | GitOps automation | [📖](./tools/fluxcd.md) |
| **Kafka (Strimzi)** | 3.8.0 | kafka | Message broker SASL | [📖](./architecture/kafka-configuration.md) |
| **cert-manager** | v1.13.1 | cert-manager | Gestion SSL Let's Encrypt | [📖](./tools/cert-manager.md) |

## 📖 Guides pratiques

| Guide | Objectif | Temps estimé |
|-------|----------|--------------|
| [Installation](./guides/installation.md) | Installer l'infrastructure complète | 1h30-2h |
| [GitOps](./guides/gitops.md) | Workflow complet de déploiement | 30min |
| [**Déploiement Automatisé**](./guides/automated-deployment.md) | Guide complet du CI/CD automatique | 45min ⭐ |

## 🔧 Opérations

| Document | Description |
|----------|-------------|
| [**Monitoring et Opérations**](./operations/monitoring.md) | Monitoring, debugging et opérations courantes ⭐ |

## 🚀 Services déployés

| Service | URL | Type | Statut |
|---------|-----|------|--------|
| **API Gateway** | https://api2.gotravelyzer.com | Public REST | ✅ Automatisé |
| **API Enrichment** | Interne uniquement | Kafka Consumer | ✅ Automatisé |
| **API Generation** | Interne uniquement | Kafka Consumer | ✅ Automatisé |

### Architecture de communication

```
Internet ──HTTPS──▶ API Gateway ──Kafka──▶ Enrichment/Generation
                        ▲                           │
                        │                           │
                        └────────── Kafka ◀────────┘
```

## ⚡ Actions rapides

```bash
# Statut global des services
kubectl get pods -n app

# Déploiement automatique (manuel)
/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/auto-deploy.sh

# Health check complet
/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/health-check.sh

# Monitoring en temps réel
kubectl logs -n app -l app=api-gateway -f

# Statut FluxCD et images
kubectl get imagerepository,imagepolicy -n flux-system
```

## 🔄 Workflow de déploiement

### 1. Push de code
```bash
git push origin main
```

### 2. Build automatique (GitHub Actions)
- Build Docker image
- Push vers GHCR avec tags `latest` + `sha-xxxxx`

### 3. Détection automatique (FluxCD - 1 minute)
- Scan des registries
- Sélection de la dernière image SHA

### 4. Déploiement automatique (CronJob - 2 minutes)
- Comparaison image actuelle vs nouvelle
- Patch automatique si différence détectée
- Rolling update sans downtime

**⏱️ Temps total : ~6 minutes maximum**

## 📊 Status actuel

### Cluster Kubernetes
```yaml
Nœuds: 1 (vps-6227e9e1)  
Status: Ready ✅
Applications: 3/3 Running ✅
Kafka: 3/3 Running ✅
FluxCD: 6/6 Running ✅
Auto-deploy: CronJob actif ✅
```

### Applications
```yaml
api-gateway: 1/1 Running ✅ (Déploiement automatisé)
api-enrichment: 1/1 Running ✅ (Déploiement automatisé)
api-generation: 1/1 Running ✅ (Déploiement automatisé)
```

### Automation CI/CD
```yaml
GitHub Actions: ✅ Build + Push GHCR
FluxCD Scanner: ✅ Détection images (1min)
ImagePolicies: ✅ Sélection SHA tags
Auto-Deploy CronJob: ✅ Déploiement (2min)
```

## 🔧 Configuration technique

### Tags d'images
- **Format** : `sha-{commit-hash}` pour traçabilité
- **Registry** : GitHub Container Registry (GHCR)
- **Détection** : FluxCD ImageRepository + ImagePolicy
- **Déploiement** : CronJob avec comparaison d'images

### Sécurité
- **Services exposition** : API Gateway seul (HTTPS)
- **Communication interne** : Kafka avec SASL SCRAM-SHA-512
- **Secrets** : Kubernetes Secrets + SOPS/age
- **Réseau** : Services internes non exposés au web

## 🚨 Troubleshooting rapide

### Problèmes courants

| Symptôme | Solution rapide |
|----------|----------------|
| Service non déployé | `/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/auto-deploy.sh` |
| Image non détectée | `kubectl describe imagerepository SERVICE -n flux-system` |
| Pod en crash | `kubectl logs -n app -l app=SERVICE --tail=50` |
| Kafka déconnecté | `kubectl rollout restart deployment -n app` |

### Commandes de debug
```bash
# Status complet
kubectl get pods -n app
kubectl get imagerepository,imagepolicy -n flux-system
kubectl get cronjob,jobs -n app

# Logs détaillés
kubectl logs -n app -l job-name --tail=20
kubectl logs -n app -l app=api-gateway --tail=50

# Forcer un redéploiement
kubectl rollout restart deployment/SERVICE -n app
```

## 📈 Métriques de performance

### Temps de déploiement
- **Build GitHub Actions** : ~2-3 minutes
- **Détection FluxCD** : ~1 minute  
- **Déploiement CronJob** : ~2 minutes max
- **Total** : ~6 minutes

### Ressources CronJob
- **CPU** : 10m request, 50m limit
- **RAM** : 32Mi request, 64Mi limit
- **Fréquence** : Toutes les 2 minutes
- **Impact** : Minimal (~2-3 secondes par exécution)

## 🔐 Sécurité

### Mesures en place
- ✅ **Services internes** : Enrichment/Generation non exposés
- ✅ **HTTPS forcé** : Let's Encrypt automatique
- ✅ **Kafka SASL** : Authentification chiffrée
- ✅ **Secrets chiffrés** : SOPS/age dans Git
- ✅ **Firewall UFW** : Ports limités
- ✅ **Rolling updates** : Pas de downtime

## 📝 Changelog

### 2025-08-11 - Déploiement automatisé complet ✅
- ✅ Configuration Kafka SASL complète (3 services)
- ✅ FluxCD ImageRepository + ImagePolicy (tous services)
- ✅ CronJob déploiement automatique opérationnel
- ✅ GitHub Actions avec tags SHA configurées
- ✅ Architecture sécurisée (services internes)
- ✅ Documentation complète générée

### 2025-08-10 - Infrastructure initiale
- ✅ Infrastructure K3s complète
- ✅ GitOps FluxCD configuré
- ✅ Applications déployées
- ✅ SSL Let's Encrypt automatique

## 🤝 Support

### Documentation détaillée
- [Guide déploiement automatisé](./guides/automated-deployment.md)
- [Configuration Kafka](./architecture/kafka-configuration.md)  
- [Monitoring et opérations](./operations/monitoring.md)

### Contacts
- **Repo GitOps** : https://github.com/team-mercurious/k3s-gitops
- **Organisation** : https://github.com/team-mercurious

---

*Documentation mise à jour le 2025-08-11*  
*Infrastructure v2.0 - Déploiement automatisé opérationnel* ✅