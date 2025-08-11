# Gestion des Secrets - Guide Complet

## Vue d'ensemble

Ce document décrit la gestion sécurisée des secrets et variables d'environnement dans l'infrastructure Kubernetes, utilisant SOPS/age pour le chiffrement et les Secrets Kubernetes pour le déploiement.

## Architecture des Secrets

### Structure organisée par microservice

```
apps/
├── api-gateway/
│   ├── env-secret.yaml          # Variables spécifiques gateway (chiffrées)
│   └── deployment.yaml          # Référence le secret
├── api-enrichment/
│   ├── env-secret.yaml          # Variables spécifiques enrichment (chiffrées)
│   └── deployment.yaml
└── api-generation/
    ├── env-secret.yaml          # Variables spécifiques generation (chiffrées)
    └── deployment.yaml
```

### Types de secrets gérés

| Type | Services | Variables |
|------|----------|-----------|
| **Database** | Tous | `MONGO_URI` |
| **Cache** | Tous | `REDIS_URL` |
| **Message Broker** | Tous | `KAFKA_BROKERS` |
| **AI/ML APIs** | Gateway, Generation, Enrichment | `OPENAI_API_KEY` |
| **Maps APIs** | Gateway, Generation | `GOOGLE_PLACES_API_KEY` |
| **OAuth** | Gateway | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` |
| **Weather** | Gateway | `OPENWEATHER_API_KEY` |
| **Environment** | Gateway | `NODE_ENV`, `CLIENT_*_URL` |

## Configuration SOPS/Age

### 1. Génération des clés de chiffrement

```bash
# Créer le répertoire de configuration
mkdir -p ~/.config/sops/age

# Générer une nouvelle clé age
age-keygen -o ~/.config/sops/age/keys.txt

# Récupérer la clé publique
grep "Public key:" ~/.config/sops/age/keys.txt
# Sortie: Public key: age1fcwjeslgu5gr7dg2mnf9he2y7xn3mvc5zw8l3j0deu4uvwqsdsys5s4gj4
```

### 2. Configuration SOPS

Fichier `.sops.yaml` à la racine du projet :

```yaml
creation_rules:
  - path_regex: .*-secret\.yaml$
    age: age1fcwjeslgu5gr7dg2mnf9he2y7xn3mvc5zw8l3j0deu4uvwqsdsys5s4gj4
  - path_regex: .*secret.*\.yaml$
    age: age1fcwjeslgu5gr7dg2mnf9he2y7xn3mvc5zw8l3j0deu4uvwqsdsys5s4gj4
```

## Gestion des Variables d'Environnement

### API Gateway

Variables d'environnement pour l'API Gateway :

```bash
# Configuration application
NODE_ENV=production
CLIENT_DEV_URL=http://localhost:3000
CLIENT_PLANNER_URL=https://ia.gotravelyzer.com
CLIENT_FRONT_URL=https://gotravelyzer.com

# Services externes
MONGO_URI=mongodb+srv://admin-mercurious:***@cluster0.jqws88l.mongodb.net/mercurious
REDIS_URL=redis://default:***@redis-18853.c327.europe-west1-2.gce.redns.redis-cloud.com:18853
KAFKA_BROKERS=my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092

# API Keys
OPENAI_API_KEY=sk-proj-***
GOOGLE_PLACES_API_KEY=AIzaSy***
GOOGLE_CLIENT_ID=1006502142654-***
GOOGLE_CLIENT_SECRET=GOCSPX-***
OPENWEATHER_API_KEY=3dbb16f91b74f***
```

### API Enrichment

Variables d'environnement pour le service d'enrichissement :

```bash
# Services de base
KAFKA_BROKERS=my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
MONGO_URI=mongodb+srv://admin-mercurious:***@cluster0.jqws88l.mongodb.net/mercurious
REDIS_URL=redis://default:***@redis-18853.c327.europe-west1-2.gce.redns.redis-cloud.com:18853

# API d'intelligence artificielle
OPENAI_API_KEY=sk-proj-***
```

### API Generation

Variables d'environnement pour le service de génération :

```bash
# Services de base
KAFKA_BROKERS=my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
MONGO_URI=mongodb+srv://admin-mercurious:***@cluster0.jqws88l.mongodb.net/mercurious
REDIS_URL=redis://default:***@redis-18853.c327.europe-west1-2.gce.redns.redis-cloud.com:18853

# APIs externes
OPENAI_API_KEY=sk-proj-***
GOOGLE_PLACES_API_KEY=AIzaSy***
```

## Workflow de Gestion des Secrets

### 1. Création d'un nouveau secret

```bash
# 1. Créer le fichier secret non chiffré
cat > apps/api-gateway/env-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: api-gateway-env
  namespace: app
type: Opaque
data:
  # Encoder les valeurs en base64
  VARIABLE_NAME: $(echo "valeur" | base64 -w 0)
EOF

# 2. Chiffrer avec SOPS
sops --encrypt --in-place apps/api-gateway/env-secret.yaml

# 3. Ajouter au kustomization.yaml
echo "- env-secret.yaml" >> apps/api-gateway/kustomization.yaml
```

### 2. Modification d'un secret existant

```bash
# 1. Déchiffrer et éditer
sops apps/api-gateway/env-secret.yaml

# 2. Appliquer les changements
kubectl apply -f apps/api-gateway/env-secret.yaml

# 3. Redémarrer le déploiement pour prendre en compte les changements
kubectl rollout restart deployment/api-gateway -n app
```

### 3. Lecture d'un secret déployé

```bash
# Voir les clés disponibles
kubectl get secret api-gateway-env -n app -o jsonpath='{.data}' | jq 'keys'

# Décoder une variable spécifique
kubectl get secret api-gateway-env -n app -o jsonpath='{.data.VARIABLE_NAME}' | base64 -d
```

## Configuration des Déploiements

### Référencement des secrets dans les deployments

```yaml
# apps/api-gateway/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - secretRef:
            name: api-gateway-env  # Secret spécifique au service
        - secretRef:
            name: app-common-secrets  # Secrets partagés (existants)
```

## Commandes Utiles

### Gestion SOPS

```bash
# Chiffrer un fichier
sops --encrypt --in-place apps/*/env-secret.yaml

# Déchiffrer temporairement pour visualisation
sops --decrypt apps/api-gateway/env-secret.yaml

# Éditer un secret chiffré
sops apps/api-gateway/env-secret.yaml

# Rechiffrer avec une nouvelle clé
sops --rotate --in-place apps/*/env-secret.yaml
```

### Gestion Kubernetes

```bash
# Appliquer tous les secrets
kubectl apply -f apps/api-gateway/env-secret.yaml \
              -f apps/api-enrichment/env-secret.yaml \
              -f apps/api-generation/env-secret.yaml

# Vérifier les secrets déployés
kubectl get secrets -n app | grep env

# Redémarrer tous les déploiements
kubectl rollout restart deployment/api-gateway \
                       deployment/api-enrichment \
                       deployment/api-generation -n app

# Surveiller le déploiement
kubectl get pods -n app -w
```

### Debug et Vérification

```bash
# Tester la connectivité depuis un pod
kubectl exec -n app deployment/api-gateway -- env | grep MONGO_URI

# Vérifier les logs d'erreur
kubectl logs -n app -l app=api-gateway --tail=20

# Tester l'API Gateway
curl -s https://api2.gotravelyzer.com
```

## Sécurité et Bonnes Pratiques

### ✅ Mesures de Sécurité Implementées

- **Chiffrement au repos** : SOPS/age avec clés locales
- **Séparation des secrets** : Un secret par microservice
- **Principle of Least Privilege** : Variables par service uniquement
- **Rotation des clés** : Capacité de rechiffrer avec nouvelles clés
- **Audit trail** : Historique Git des modifications chiffrées

### 🔒 Recommandations Supplémentaires

1. **Rotation régulière** : Changer les API keys tous les 90 jours
2. **Monitoring des accès** : Surveiller les logs des secrets
3. **Backup des clés** : Sauvegarder `~/.config/sops/age/keys.txt`
4. **Accès restreint** : Limiter qui peut déchiffrer les secrets
5. **Environnements séparés** : Clés différentes pour dev/staging/prod

### 🚨 Variables Sensibles Identifiées

- `MONGO_URI` : Contains database credentials
- `REDIS_URL` : Contains cache credentials  
- `OPENAI_API_KEY` : Expensive API access
- `GOOGLE_CLIENT_SECRET` : OAuth security
- Toutes les API keys : Accès aux services payants

## Dépannage

### Problèmes Courants

1. **Secret non trouvé** :
   ```bash
   # Vérifier que le secret existe
   kubectl get secret api-gateway-env -n app
   
   # Si absent, l'appliquer
   kubectl apply -f apps/api-gateway/env-secret.yaml
   ```

2. **Variables non chargées** :
   ```bash
   # Redémarrer le déploiement
   kubectl rollout restart deployment/api-gateway -n app
   
   # Vérifier les variables dans le pod
   kubectl exec -n app deployment/api-gateway -- printenv | grep MONGO
   ```

3. **Erreur de déchiffrement SOPS** :
   ```bash
   # Vérifier que la clé age est disponible
   ls -la ~/.config/sops/age/keys.txt
   
   # Vérifier la variable d'environnement
   export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
   ```

## Workflow d'Urgence

En cas de compromission d'un secret :

```bash
# 1. Révoquer immédiatement les credentials compromis sur les services externes

# 2. Générer de nouveaux credentials

# 3. Mettre à jour le secret
sops apps/SERVICE/env-secret.yaml

# 4. Appliquer et redémarrer
kubectl apply -f apps/SERVICE/env-secret.yaml
kubectl rollout restart deployment/SERVICE -n app

# 5. Vérifier que le service fonctionne
kubectl logs -n app -l app=SERVICE --tail=10
```

---

*Documentation mise à jour le 2025-08-11*  
*Secrets management v1.0 - Production ready* ✅