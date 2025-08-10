# Guide d'Installation Complète

## 🎯 Objectif

Ce guide vous permet d'installer l'infrastructure complète K3s + GitOps sur un VPS Ubuntu 22.04/24.04 depuis zéro.

## 📋 Prérequis

### Infrastructure
```yaml
VPS Requirements:
  OS: Ubuntu 22.04 LTS ou 24.04 LTS
  CPU: 2 vCPU minimum (4 vCPU recommandé)
  RAM: 4GB minimum (8GB recommandé)
  Storage: 50GB minimum (100GB recommandé)
  Network: IPv4 public + 1Gbps
  Provider: OVH, Hetzner, DigitalOcean, etc.
```

### Accès et outils
```yaml
Required:
  - Accès SSH avec clés (pas de mot de passe)
  - Utilisateur avec sudo (ubuntu par défaut)
  - Nom de domaine pointant vers le VPS
  - GitHub account avec organisation
  - GitHub Personal Access Token

Local Tools:
  - Git
  - kubectl (optionnel)
  - flux CLI (optionnel)
```

### GitHub Setup
```bash
# 1. Créer une organisation GitHub (ex: team-mercurious)
# 2. Créer un Personal Access Token avec permissions:
#    - repo (Full control of private repositories)
#    - write:packages (Upload packages to GitHub Package Registry)
#    - admin:org (si vous voulez créer des repos dans l'org)
```

## 🚀 Installation Automatisée

### Méthode rapide (recommandée)
```bash
# 1. Se connecter au VPS
ssh ubuntu@your-vps-ip

# 2. Cloner le repository
git clone https://github.com/team-mercurious/infrastructure.git
cd infrastructure

# 3. Lancer le bootstrap
./scripts/bootstrap.sh
```

Le script `bootstrap.sh` va automatiquement :
- ✅ Mettre à jour le système Ubuntu
- ✅ Configurer la sécurité (UFW, fail2ban)
- ✅ Installer K3s
- ✅ Installer les outils (Helm, FluxCD CLI, SOPS, age)
- ✅ Déployer cert-manager
- ✅ Installer le monitoring (Prometheus + Grafana)
- ✅ Afficher les informations de connexion

## 🔧 Installation Manuelle

Si vous préférez contrôler chaque étape :

### 1. Mise à jour système
```bash
# Mise à jour des packages
sudo apt update && sudo apt upgrade -y

# Installation des outils de base
sudo apt install -y curl wget git vim htop tree jq unzip
```

### 2. Configuration sécurité
```bash
# Configuration UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 6443/tcp  # K3s API
sudo ufw --force enable

# Installation fail2ban
sudo apt install -y fail2ban

# Configuration fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Updates automatiques
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 3. Installation K3s
```bash
# Installation K3s avec kubeconfig accessible
export K3S_KUBECONFIG_MODE="644"
curl -sfL https://get.k3s.io | sh -

# Configuration kubectl pour l'utilisateur
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérification
kubectl get nodes
kubectl get pods -A
```

### 4. Installation des outils
```bash
# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# FluxCD CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# SOPS
wget https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64 -O /tmp/sops
sudo mv /tmp/sops /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops

# age
wget https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz -O /tmp/age.tar.gz
tar -xzf /tmp/age.tar.gz -C /tmp
sudo mv /tmp/age/age* /usr/local/bin/
rm -rf /tmp/age*

# Vérification des versions
helm version
flux version
sops --version
age --version
```

### 5. Installation cert-manager
```bash
# Ajout du repository Helm
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Installation cert-manager
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.13.1 \
  --set installCRDs=true

# Attendre que cert-manager soit prêt
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager -n cert-manager --timeout=300s

# Vérification
kubectl get pods -n cert-manager
```

### 6. Installation monitoring
```bash
# Ajout des repositories Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Installation du stack monitoring
kubectl create namespace monitoring
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=5Gi

# Vérification
kubectl get pods -n monitoring
```

## 🔄 Configuration GitOps

### 1. Génération des clés age
```bash
# Générer une clé age pour SOPS
age-keygen -o age.agekey

# Sauvegarder la clé publique
PUBLIC_KEY=$(cat age.agekey | head -n1 | cut -d' ' -f3)
echo "Clé publique age: $PUBLIC_KEY"

# Configuration SOPS
cat > .sops.yaml <<EOF
creation_rules:
  - path_regex: \.sops\.yaml$
    age: $PUBLIC_KEY
  - path_regex: secret.*\.yaml$
    age: $PUBLIC_KEY
EOF
```

### 2. Bootstrap FluxCD
```bash
# Variables d'environnement
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="team-mercurious"
export GITHUB_REPO="k3s-gitops"

# Vérification des prérequis
flux check --pre

# Bootstrap FluxCD
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/vps \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller

# Vérification
kubectl get pods -n flux-system
flux get all
```

### 3. Configuration des secrets
```bash
# Secret age pour SOPS
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=age.agekey

# Secret pour GHCR (GitHub Container Registry)
kubectl create secret docker-registry ghcr-secret \
  --namespace flux-system \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=your-email@example.com
```

## 📁 Structure GitOps

### 1. Cloner et organiser le repository
```bash
# Cloner le repository GitOps créé par FluxCD
git clone https://github.com/$GITHUB_USER/$GITHUB_REPO.git
cd $GITHUB_REPO

# Créer la structure
mkdir -p {infra,apps,security}
mkdir -p apps/{api-gateway,api-generation,api-enrichment}
```

### 2. Configuration infrastructure
```yaml
# infra/le-prod.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          ingressClassName: traefik
```

### 3. Configuration des applications
```yaml
# apps/api-gateway/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: app
        image: ghcr.io/team-mercurious/api-gateway:latest # {"$imagepolicy": "flux-system:api-gateway:tag"}
        ports:
        - containerPort: 3000
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
```

### 4. Kustomizations FluxCD
```yaml
# clusters/vps/infra.yaml
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

---
# clusters/vps/apps.yaml
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

### 5. Commit et push
```bash
git add .
git commit -m "Initial GitOps structure"
git push origin main
```

## ✅ Vérification de l'installation

### 1. Cluster Kubernetes
```bash
# Status général
kubectl get nodes
kubectl get pods -A

# Vérifier les namespaces
kubectl get namespaces

# Resources utilisées
kubectl top nodes
kubectl top pods -A
```

### 2. FluxCD
```bash
# Status FluxCD
flux get all

# Vérifier les sources Git
flux get sources git

# Vérifier les kustomizations
flux get kustomizations
```

### 3. Applications
```bash
# Pods d'application
kubectl get pods -n app

# Services et ingress
kubectl get svc,ingress -n app

# Logs des applications
kubectl logs -n app deployment/api-gateway
```

### 4. Monitoring
```bash
# Port-forward Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

# Ouvrir http://localhost:3000
# Login: admin / admin123
```

### 5. SSL/TLS
```bash
# Vérifier les certificats
kubectl get certificates -A

# Vérifier les ClusterIssuers
kubectl get clusterissuer

# Test HTTPS
curl -I https://your-domain.com
```

## 🐛 Troubleshooting Installation

### Problèmes courants

**1. K3s ne démarre pas**
```bash
# Vérifier les logs
sudo journalctl -u k3s -n 50

# Vérifier l'espace disque
df -h

# Redémarrer K3s
sudo systemctl restart k3s
```

**2. FluxCD bootstrap échoue**
```bash
# Vérifier les permissions GitHub token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Vérifier la connectivité
ping github.com

# Re-essayer le bootstrap
flux bootstrap github --force
```

**3. Pods en CrashLoopBackOff**
```bash
# Vérifier les logs
kubectl logs pod-name -n namespace

# Vérifier les events
kubectl get events --sort-by='.firstTimestamp' -n namespace

# Vérifier les resources
kubectl describe pod pod-name -n namespace
```

## 📈 Post-Installation

### 1. Configuration DNS
```bash
# Pointer votre domaine vers l'IP du VPS
# A Record: your-domain.com -> VPS_IP
# A Record: *.your-domain.com -> VPS_IP (pour les sous-domaines)
```

### 2. Monitoring setup
```bash
# Configurer des alertes
# Créer des dashboards personnalisés
# Setup notifications (Slack, email, etc.)
```

### 3. Backup strategy
```bash
# Backup des secrets age
cp age.agekey ~/backup-age-$(date +%Y%m%d).agekey

# Backup de la configuration K3s
sudo cp -r /var/lib/rancher/k3s ~/backup-k3s-$(date +%Y%m%d)
```

### 4. Documentation
```bash
# Documenter les URLs d'accès
# Créer un runbook des procédures
# Former l'équipe aux outils déployés
```

## ⏱️ Temps d'installation

```yaml
Estimation:
  Installation automatique: 15-20 minutes
  Installation manuelle: 45-60 minutes
  Configuration GitOps: 30-45 minutes
  Tests et vérification: 15-30 minutes
  Total: 1h30 à 2h30
```

## 🔗 Ressources

- [Bootstrap Script](../scripts/bootstrap.sh)
- [Architecture Overview](../architecture/overview.md)
- [GitOps Guide](./gitops.md)
- [Monitoring Guide](./monitoring.md)