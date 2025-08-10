# Guide GitOps Workflow

## 📖 Overview du GitOps

GitOps est une méthodologie de déploiement continu qui utilise Git comme source de vérité unique pour l'infrastructure et les applications. Chaque changement passe par Git, permettant versioning, review, et rollback automatiques.

## 🔄 Workflow GitOps Complet

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │    GitHub       │    │   Kubernetes    │
│                 │    │                 │    │    Cluster      │
│                 │    │                 │    │                 │
│  1. Code Push   │───▶│  2. CI/CD       │───▶│  3. FluxCD      │
│     (main)      │    │     Actions     │    │     Sync        │
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   git     │  │    │  │   Build   │  │    │  │   Apply   │  │
│  │  commit   │  │    │  │   Test    │  │    │  │ Manifests │  │
│  │   push    │  │    │  │   Push    │  │    │  │           │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         │                        ▼                        │
         │              ┌─────────────────┐                │
         │              │     GHCR        │                │
         │              │   Container     │                │
         │              │   Registry      │                │
         │              └─────────────────┘                │
         │                        │                        │
         │                        ▼                        │
         │              ┌─────────────────┐                │
         │              │   FluxCD Auto   │                │
         │              │  Image Update   │◀───────────────┘
         │              │   (30min scan)  │
         │              └─────────────────┘
         │                        │
         └────────────────────────┘
              Git commit with new image tag
```

## 🏗️ Repository Structure

### Structure du repository GitOps
```
team-mercurious/k3s-gitops/
├── clusters/vps/              # Configuration spécifique au cluster
│   ├── flux-system/           # FluxCD auto-généré
│   ├── infra.yaml            # Kustomization infrastructure
│   ├── apps.yaml             # Kustomization applications
│   └── image-automation.yaml  # Automation des images
│
├── infra/                     # Infrastructure comme code
│   ├── cert-manager/
│   │   ├── le-prod.yaml      # ClusterIssuer production
│   │   └── le-staging.yaml   # ClusterIssuer staging
│   ├── traefik/
│   │   └── ingress-api-gateway.yaml
│   └── kustomization.yaml
│
├── apps/                      # Applications
│   ├── api-gateway/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── hpa.yaml
│   │   ├── imagerepository.yaml
│   │   ├── imagepolicy.yaml
│   │   └── kustomization.yaml
│   ├── api-generation/
│   └── api-enrichment/
│
└── security/                  # Secrets chiffrés
    ├── secret-kafka.sops.yaml
    └── secret-app.sops.yaml
```

## 🚀 Déploiement d'une nouvelle application

### 1. Créer les manifests Kubernetes
```bash
# Créer le répertoire de l'application
mkdir -p apps/my-new-app

# Deployment
cat > apps/my-new-app/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-new-app
  namespace: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-new-app
  template:
    metadata:
      labels:
        app: my-new-app
    spec:
      containers:
      - name: app
        image: ghcr.io/team-mercurious/my-new-app:latest # {"$imagepolicy": "flux-system:my-new-app:tag"}
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /health  
            port: 8080
          initialDelaySeconds: 10
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
EOF
```

### 2. Service et Ingress
```bash
# Service
cat > apps/my-new-app/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: my-new-app
  namespace: app
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-new-app
EOF

# Ingress
cat > apps/my-new-app/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-new-app
  namespace: app
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - myapp.gotravelyzer.com
    secretName: my-new-app-tls
  rules:
  - host: myapp.gotravelyzer.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-new-app
            port:
              number: 80
EOF
```

### 3. Kustomization
```bash
cat > apps/my-new-app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml

namespace: app

commonLabels:
  app.kubernetes.io/name: my-new-app
  app.kubernetes.io/part-of: mercurious-platform
EOF
```

### 4. Image Automation
```bash
# ImageRepository
cat > apps/my-new-app/imagerepository.yaml <<EOF
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: my-new-app
  namespace: flux-system
spec:
  image: ghcr.io/team-mercurious/my-new-app
  interval: 1m0s
  secretRef:
    name: ghcr-secret
EOF

# ImagePolicy
cat > apps/my-new-app/imagepolicy.yaml <<EOF
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: my-new-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: my-new-app
  policy:
    alphabetical:
      order: asc
  filterTags:
    pattern: '^sha-[a-f0-9]+'
    extract: '$0'
EOF
```

### 5. Commit et déploiement
```bash
# Ajouter les fichiers
git add apps/my-new-app/

# Commit
git commit -m "Add my-new-app deployment manifests

- Deployment with 2 replicas
- Service ClusterIP on port 80
- Ingress with TLS (myapp.gotravelyzer.com)
- Image automation setup
- Health checks configured"

# Push
git push origin main

# FluxCD va détecter et déployer automatiquement
```

## 🔄 Mise à jour d'une application

### Via Image Automation (recommandé)
```bash
# 1. Push du code dans le repository applicatif
git push origin main

# 2. GitHub Actions build et push l'image
# ghcr.io/team-mercurious/my-app:sha-abc123

# 3. FluxCD scanne le registry (1 min)
flux get images repository my-app

# 4. FluxCD met à jour automatiquement le YAML
# 5. FluxCD redéploie l'application
```

### Via modification manuelle
```bash
# Éditer le deployment
vim apps/my-app/deployment.yaml

# Changer l'image tag
# image: ghcr.io/team-mercurious/my-app:v1.2.0

# Commit et push
git add apps/my-app/deployment.yaml
git commit -m "Update my-app to v1.2.0"
git push origin main
```

## 🔐 Gestion des secrets

### 1. Créer un secret chiffré
```bash
# Générer la clé age (si pas déjà fait)
age-keygen -o age.agekey

# Exporter la clé pour SOPS
export SOPS_AGE_KEY_FILE=age.agekey

# Créer un secret Kubernetes
kubectl create secret generic my-app-secrets \
  --from-literal=DATABASE_URL="postgresql://user:pass@host:5432/db" \
  --from-literal=API_KEY="super-secret-key" \
  --dry-run=client -o yaml > /tmp/my-secret.yaml

# Chiffrer avec SOPS
sops --encrypt /tmp/my-secret.yaml > security/secret-my-app.sops.yaml

# Nettoyer le temporaire
rm /tmp/my-secret.yaml
```

### 2. Référencer le secret dans l'application
```yaml
# apps/my-app/deployment.yaml
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: my-app-secrets
              key: DATABASE_URL
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: my-app-secrets
              key: API_KEY
```

### 3. Commit du secret chiffré
```bash
git add security/secret-my-app.sops.yaml
git commit -m "Add encrypted secrets for my-app"
git push origin main
```

## 📊 Monitoring du GitOps

### Status FluxCD
```bash
# Vue d'ensemble
flux get all

# Sources Git
flux get sources git

# Kustomizations  
flux get kustomizations

# Image automation
flux get images all

# Logs en temps réel
flux logs --follow --tail=20
```

### Métriques Prometheus
```promql
# Nombre de réconciliations réussies
gotk_reconcile_condition{type="Ready", status="True"}

# Durée des réconciliations
histogram_quantile(0.95, gotk_reconcile_duration_bucket)

# Taux d'erreurs
rate(gotk_reconcile_condition{type="Ready", status="False"}[5m])
```

### Alerts recommandées
```yaml
groups:
- name: fluxcd
  rules:
  - alert: FluxReconciliationFailure
    expr: gotk_reconcile_condition{type="Ready", status="False"} == 1
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "FluxCD reconciliation failing"
      description: "{{ $labels.name }} has been failing for 15 minutes"
      
  - alert: FluxSuspended
    expr: gotk_suspend_status == 1
    for: 0m
    labels:
      severity: info
    annotations:
      summary: "FluxCD resource suspended"
      description: "{{ $labels.name }} is suspended"
```

## 🔧 Troubleshooting GitOps

### Réconciliation bloquée
```bash
# Forcer la réconciliation
flux reconcile source git flux-system
flux reconcile kustomization apps

# Vérifier les events
kubectl get events -n flux-system --sort-by='.firstTimestamp'

# Logs détaillés
kubectl logs -n flux-system deploy/kustomize-controller -f
```

### Erreurs SOPS
```bash
# Vérifier le secret age
kubectl get secret sops-age -n flux-system -o yaml

# Tester SOPS localement
export SOPS_AGE_KEY_FILE=age.agekey
sops -d security/secret-kafka.sops.yaml

# Recréer le secret si nécessaire
kubectl delete secret sops-age -n flux-system
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=age.agekey
```

### Image automation bloquée
```bash
# Status des image resources
flux get images repository api-gateway
flux get images policy api-gateway
flux get images update flux-system

# Logs des controllers
kubectl logs -n flux-system deploy/image-reflector-controller -f
kubectl logs -n flux-system deploy/image-automation-controller -f

# Test manuel du registry
docker pull ghcr.io/team-mercurious/api-gateway:latest
```

## 🚦 Stratégies de déploiement

### Blue/Green Deployment
```yaml
# Utilisation des labels pour le traffic switching
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
    version: blue  # ou green
```

### Canary Deployment avec Flagger
```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: my-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  service:
    port: 80
  analysis:
    interval: 30s
    threshold: 10
    maxWeight: 50
    stepWeight: 10
```

### Feature Flags
```yaml
# ConfigMap pour les feature flags
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
data:
  NEW_FEATURE_ENABLED: "true"
  BETA_FEATURE_ENABLED: "false"
```

## 📈 Optimisation du GitOps

### Réduction du temps de sync
```yaml
# Ajustement des intervalles
spec:
  interval: 1m0s  # Pour les environnements dev
  interval: 5m0s  # Pour production
```

### Parallelisation des déploiements
```yaml
# Kustomizations indépendantes
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: frontend
spec:
  dependsOn: []  # Pas de dépendance

---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2  
kind: Kustomization
metadata:
  name: backend
spec:
  dependsOn:
  - name: database
```

## 🔄 Rollback

### Rollback via Git
```bash
# Identifier le commit à rollback
git log --oneline

# Revert du commit
git revert commit-hash

# Push pour déclencher le rollback
git push origin main
```

### Rollback via kubectl (urgence)
```bash
# Rollback d'un deployment
kubectl rollout undo deployment/my-app -n app

# Puis fixer le Git pour éviter les conflits
```

## 📚 Best Practices

### Structure des commits
```bash
# Format recommandé
git commit -m "type(scope): description

- Detail 1
- Detail 2

Closes #123"

# Exemples
git commit -m "feat(api-gateway): add health check endpoint"
git commit -m "fix(monitoring): correct Grafana datasource config"
git commit -m "chore(k8s): update ingress annotations"
```

### Pull Requests
```yaml
Process:
  1. Créer une branch feature
  2. Faire les modifications
  3. Tester localement avec kubectl apply --dry-run
  4. Créer une Pull Request
  5. Review par l'équipe
  6. Merge vers main
  7. FluxCD déploie automatiquement
```

### Testing
```bash
# Validation des manifests
kubectl apply --dry-run=server -k apps/

# Validation avec kustomize
kustomize build apps/ | kubectl apply --dry-run=server -f -

# Tests de sécurité
trivy config apps/
```

## 🔗 Resources

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [GitOps Principles](https://www.gitops.tech/)
- [Kustomize Documentation](https://kustomize.io/)
- [SOPS Documentation](https://github.com/mozilla/sops)