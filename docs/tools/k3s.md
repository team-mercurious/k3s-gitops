# Kubernetes (K3s)

## 📖 Overview

K3s est une distribution Kubernetes légère, parfaite pour les environnements edge, IoT, et single-node. Elle inclut tout ce qui est nécessaire pour faire fonctionner Kubernetes dans un binaire de moins de 100MB.

## 🚀 Installation

### Installation automatique
```bash
curl -sfL https://get.k3s.io | sh -
```

### Installation personnalisée (utilisée)
```bash
export K3S_KUBECONFIG_MODE="644"
curl -sfL https://get.k3s.io | sh -
```

## ⚙️ Configuration

### Fichiers de configuration
```yaml
Service: /etc/systemd/system/k3s.service
Kubeconfig: /etc/rancher/k3s/k3s.yaml
Data Directory: /var/lib/rancher/k3s/
Logs: journalctl -u k3s
```

### Configuration actuelle
```yaml
Version: v1.33.3+k3s1
Mode: Single Node
etcd: Embedded (SQLite)
Container Runtime: containerd
Network: Flannel CNI
Storage: local-path-provisioner
Ingress: Traefik (enabled)
Load Balancer: ServiceLB
DNS: CoreDNS
```

## 🛠️ Commandes utiles

### Status et informations
```bash
# Status du service K3s
sudo systemctl status k3s

# Version K3s
k3s --version

# Informations sur le nœud
kubectl get nodes -o wide

# Status de tous les pods système
kubectl get pods -A

# Ressources du cluster
kubectl top nodes
kubectl top pods -A
```

### Gestion du service
```bash
# Démarrer K3s
sudo systemctl start k3s

# Arrêter K3s
sudo systemctl stop k3s

# Redémarrer K3s
sudo systemctl restart k3s

# Activer au démarrage
sudo systemctl enable k3s

# Logs en temps réel
sudo journalctl -u k3s -f
```

### Configuration kubectl
```bash
# Copier kubeconfig pour l'utilisateur
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Tester la connexion
kubectl get nodes
```

## 🔧 Composants intégrés

### Traefik Ingress Controller
```yaml
Namespace: kube-system
Service: traefik
Type: LoadBalancer
Ports: 80, 443
Dashboard: Disabled by default
```

**Configuration personnalisée :**
```yaml
# Activer le dashboard (optionnel)
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    dashboard:
      enabled: true
      domain: traefik.local
```

### CoreDNS
```yaml
Service: DNS résolution interne
Namespace: kube-system
Config: /var/lib/rancher/k3s/server/manifests/coredns.yaml
```

### Local Path Provisioner
```yaml
Purpose: Storage dynamique
Path: /opt/local-path-provisioner/
StorageClass: local-path (default)
```

## 📊 Monitoring K3s

### Métriques importantes
```bash
# CPU et mémoire des nœuds
kubectl top nodes

# Utilisation par namespace  
kubectl top pods -A --sort-by=cpu

# Events du cluster
kubectl get events --sort-by='.firstTimestamp'

# Status des composants
kubectl get componentstatuses
```

### Health checks
```bash
# Vérifier que K3s fonctionne
kubectl get nodes
kubectl get pods -n kube-system

# Vérifier les services critiques
kubectl get svc -n kube-system

# Vérifier le stockage
kubectl get pv
kubectl get sc
```

## 🔒 Sécurité K3s

### RBAC (Role-Based Access Control)
```yaml
# Lister les rôles
kubectl get clusterroles
kubectl get roles -A

# Lister les bindings
kubectl get clusterrolebindings
kubectl get rolebindings -A
```

### Network Policies
```yaml
# Lister les politiques réseau
kubectl get networkpolicies -A

# Exemple de politique restrictive
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Pod Security Standards
```yaml
# Vérifier les contextes de sécurité
kubectl get pods -o jsonpath='{.items[*].spec.securityContext}'

# Lister les Pod Security Policies (si activé)
kubectl get psp
```

## 🗂️ Structure des données K3s

### Répertoires importants
```bash
/var/lib/rancher/k3s/
├── agent/                 # Configuration agent
├── data/                  # Données etcd/containerd  
├── server/
│   ├── manifests/         # Manifests auto-appliqués
│   ├── static/            # Pods statiques
│   └── tls/              # Certificats TLS
└── storage/               # Volumes persistants
```

### Manifests auto-déployés
```bash
/var/lib/rancher/k3s/server/manifests/
├── ccm.yaml              # Cloud Controller Manager
├── coredns.yaml          # DNS
├── local-storage.yaml    # Stockage local
├── metrics-server.yaml   # Métriques
├── rolebindings.yaml     # RBAC
└── traefik.yaml         # Ingress
```

## 🔧 Troubleshooting

### Problèmes courants

**1. Nœud "NotReady"**
```bash
# Vérifier les logs
sudo journalctl -u k3s -n 50

# Vérifier l'espace disque
df -h

# Redémarrer K3s
sudo systemctl restart k3s
```

**2. Pods en "Pending"**
```bash
# Vérifier les resources
kubectl describe node

# Vérifier les events
kubectl get events --sort-by='.firstTimestamp'

# Vérifier les taints
kubectl describe node | grep -i taint
```

**3. Problèmes de réseau**
```bash
# Tester la résolution DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Vérifier Flannel
kubectl get pods -n kube-flannel

# Tester la connectivité inter-pods
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never
```

## 📈 Mise à jour K3s

### Mise à jour manuelle
```bash
# Nouvelle version
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.28.5+k3s1" sh -

# Vérifier la version
kubectl version

# Vérifier les nœuds
kubectl get nodes
```

### Système Upgrade Controller (automatique)
```yaml
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata:
  name: server-plan
  namespace: system-upgrade
spec:
  concurrency: 1
  cordon: true
  nodeSelector:
    matchExpressions:
    - key: node-role.kubernetes.io/control-plane
      operator: In
      values:
      - "true"
  serviceAccountName: system-upgrade
  upgrade:
    image: rancher/k3s-upgrade
  version: v1.28.5+k3s1
```

## ⚡ Performance

### Optimisations recommandées
```yaml
# Désactiver des composants non utilisés
K3S_DISABLE="traefik,servicelb,local-storage"

# Réserver des ressources
--kubelet-arg="kube-reserved=cpu=500m,memory=500Mi"
--kubelet-arg="system-reserved=cpu=500m,memory=500Mi"

# Augmenter les limites
--kube-apiserver-arg="max-requests-inflight=2000"
```

### Métriques de performance
```bash
# Utilisation des ressources
kubectl top nodes
kubectl top pods -A

# Latence API server
kubectl get --raw /metrics | grep apiserver_request_duration

# Throughput réseau
kubectl get --raw /metrics | grep network
```

## 🔗 Intégrations

### Avec FluxCD
```yaml
# FluxCD surveille le cluster
kubectl get gitrepositories -n flux-system

# Auto-sync des manifests
kubectl get kustomizations -n flux-system
```

### Avec Prometheus
```yaml
# Métriques K3s exposées
curl http://localhost:10249/metrics  # kube-proxy
curl http://localhost:10250/metrics  # kubelet
```

### Avec External Services
```yaml
# Services externes (MongoDB, Redis)
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
```

## 📚 Resources utiles

- **Documentation officielle** : https://docs.k3s.io/
- **GitHub** : https://github.com/k3s-io/k3s
- **Community** : https://slack.rancher.io/
- **Architecture** : https://docs.k3s.io/architecture