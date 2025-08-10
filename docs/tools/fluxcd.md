# FluxCD GitOps

## 📖 Overview

FluxCD est un outil GitOps pour Kubernetes qui synchronise automatiquement l'état du cluster avec un repository Git. Il permet un déploiement continu déclaratif et sécurisé.

## 🚀 Installation et Configuration

### Installation CLI
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

### Bootstrap sur le cluster
```bash
export GITHUB_TOKEN="your-token"
export GITHUB_USER="team-mercurious"
export GITHUB_REPO="k3s-gitops"

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/vps \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller
```

## 🏗️ Architecture FluxCD

### Controllers déployés
```yaml
source-controller:
  Purpose: Git/Helm repositories management
  Version: v1.2.4
  
kustomize-controller:
  Purpose: Apply Kustomization resources
  Version: v1.2.2
  
helm-controller:
  Purpose: Manage Helm releases
  Version: v0.37.4
  
notification-controller:
  Purpose: Webhooks and alerts
  Version: v1.2.4
  
image-reflector-controller:
  Purpose: Scan container registries
  Version: v0.31.2
  
image-automation-controller:
  Purpose: Automated image updates
  Version: v0.37.1
```

## 🔄 GitOps Workflow

### 1. Source Configuration
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  url: https://github.com/team-mercurious/k3s-gitops
```

### 2. Kustomization Resources
```yaml
# Infrastructure
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: infra
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./infra
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system

# Applications  
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./apps
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
  dependsOn:
    - name: infra
```

## 🖼️ Image Automation

### Image Repository Scanning
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

### Image Policy
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
      order: asc
  filterTags:
    pattern: '^sha-[a-f0-9]+'
    extract: '$0'
```

### Image Update Automation
```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 30m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
      messageTemplate: |
        Automated image update
        
        Images:
        {{- range .Updated.Images }}
        - {{.}}
        {{- end }}
    push:
      branch: main
  update:
    path: "./k3s-gitops"
    strategy: Setters
```

## 🔐 Secrets Management

### SOPS Integration
```yaml
# Secret contenant la clé age
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=age.agekey

# Configuration SOPS
cat > .sops.yaml <<EOF
creation_rules:
  - path_regex: \.sops\.yaml$
    age: age1e3z2qzqmxrhnp9ar07xs60qhwgaxaz8tn00464qkttkny4jn6gwsp5uavd
  - path_regex: secret.*\.yaml$
    age: age1e3z2qzqmxrhnp9ar07xs60qhwgaxaz8tn00464qkttkny4jn6gwsp5uavd
EOF
```

### Registry Authentication
```yaml
# Secret pour GHCR
kubectl create secret docker-registry ghcr-secret \
  --namespace flux-system \
  --docker-server=ghcr.io \
  --docker-username=Tekdey \
  --docker-password=TOKEN \
  --docker-email=devw.nbardi@gmail.com
```

## 🛠️ Commandes FluxCD

### Status et monitoring
```bash
# Status général
flux get all

# Status des sources Git
flux get sources git

# Status des kustomizations
flux get kustomizations

# Status de l'automation d'images
flux get images all

# Logs des controllers
flux logs --follow --tail=10
```

### Réconciliation manuelle
```bash
# Forcer sync d'une source Git
flux reconcile source git flux-system

# Forcer apply d'une kustomization
flux reconcile kustomization apps

# Forcer scan d'une image
flux reconcile image repository api-gateway

# Forcer update automation
flux reconcile image update flux-system
```

### Suspension et reprise
```bash
# Suspendre une kustomization
flux suspend kustomization apps

# Reprendre une kustomization
flux resume kustomization apps

# Suspendre l'automation d'images
flux suspend image update flux-system
```

## 📊 Monitoring FluxCD

### Health Checks
```bash
# Vérifier que tous les controllers sont healthy
kubectl get pods -n flux-system

# Events FluxCD
kubectl get events -n flux-system --sort-by='.firstTimestamp'

# Status des CRDs
kubectl get crds | grep fluxcd
```

### Métriques Prometheus
```yaml
# FluxCD expose des métriques sur :8080/metrics
Metrics:
  - gotk_reconcile_duration
  - gotk_reconcile_condition
  - gotk_suspend_status
  - controller_runtime_*
```

### Alerts
```yaml
# Exemple d'alerte Prometheus
- alert: FluxcdReconciliationFailure
  expr: gotk_reconcile_condition{type="Ready", status="False"} == 1
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "FluxCD reconciliation failing"
    description: "{{ $labels.name }} in {{ $labels.namespace }} failing for 15m"
```

## 🔧 Troubleshooting

### Problèmes courants

**1. GitRepository not ready**
```bash
# Vérifier l'accès au repository
flux get sources git

# Logs du source-controller
kubectl logs -n flux-system deploy/source-controller

# Tester l'accès Git manuellement
git ls-remote https://github.com/team-mercurious/k3s-gitops.git
```

**2. Kustomization failing**
```bash
# Détails de l'erreur
kubectl describe kustomization apps -n flux-system

# Tester kustomize localement
kustomize build ./apps

# Valider les manifests
kubectl apply --dry-run=server -k ./apps
```

**3. SOPS decryption errors**
```bash
# Vérifier le secret age
kubectl get secret sops-age -n flux-system -o yaml

# Tester SOPS manuellement
export SOPS_AGE_KEY_FILE=age.agekey
sops -d security/secret-kafka.sops.yaml
```

**4. Image automation not working**
```bash
# Status des image resources
flux get images all

# Logs du image-reflector-controller
kubectl logs -n flux-system deploy/image-reflector-controller

# Logs du image-automation-controller  
kubectl logs -n flux-system deploy/image-automation-controller

# Vérifier l'authentification registry
kubectl get secret ghcr-secret -n flux-system -o yaml
```

## 🚀 CI/CD Integration

### GitHub Actions Example
```yaml
name: Update Image Tag
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build and push
      run: |
        docker build -t ghcr.io/team-mercurious/api-gateway:sha-${GITHUB_SHA} .
        docker push ghcr.io/team-mercurious/api-gateway:sha-${GITHUB_SHA}
        
    # FluxCD détectera automatiquement la nouvelle image
```

### Deployment Markers
```yaml
# Dans deployment.yaml
spec:
  template:
    spec:
      containers:
      - name: app
        image: ghcr.io/team-mercurious/api-gateway:latest # {"$imagepolicy": "flux-system:api-gateway:tag"}
```

## 📈 Best Practices

### Repository Structure
```
k3s-gitops/
├── clusters/vps/          # Cluster-specific config
│   ├── flux-system/       # FluxCD manifests (auto-generated)
│   ├── infra.yaml         # Infrastructure kustomization
│   ├── apps.yaml          # Applications kustomization
│   └── image-automation.yaml
├── infra/                 # Infrastructure manifests
│   ├── cert-manager/
│   ├── traefik/
│   └── monitoring/
├── apps/                  # Application manifests
│   ├── api-gateway/
│   ├── api-generation/
│   └── api-enrichment/
└── security/              # Encrypted secrets
    └── *.sops.yaml
```

### Security
```yaml
Best Practices:
  - Use SOPS for all secrets
  - Least privilege RBAC for FluxCD
  - Private Git repositories
  - Signed commits (optional)
  - Separate environments (dev/staging/prod)
```

### Performance
```yaml
Optimizations:
  - Adjust reconciliation intervals based on needs
  - Use git shallow clones for large repos
  - Implement proper resource requests/limits
  - Monitor controller metrics
```

## 📚 Advanced Features

### Multi-tenancy
```yaml
# Separate kustomizations per tenant
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: tenant-a
  namespace: flux-system
spec:
  path: ./tenants/tenant-a
  targetNamespace: tenant-a
  serviceAccountName: tenant-a-reconciler
```

### Progressive Delivery
```yaml
# Integration avec Flagger pour canary deployments
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: api-gateway
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  service:
    port: 80
  analysis:
    interval: 1m
    threshold: 10
    maxWeight: 50
```

### Notifications
```yaml
# Slack notifications
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Alert
metadata:
  name: slack-alert
spec:
  providerRef:
    name: slack
  eventSeverity: info
  eventSources:
    - kind: Kustomization
      name: apps
    - kind: ImageRepository
      name: '*'
```

## 🔗 Resources

- **Documentation** : https://fluxcd.io/docs/
- **GitHub** : https://github.com/fluxcd/flux2
- **Community** : https://cloud-native.slack.com/#fluxcd
- **Examples** : https://github.com/fluxcd/flux2-kustomize-helm-example