# Components détaillés

## 🏗️ Infrastructure Components

### 1. **Kubernetes (K3s)**

```yaml
Version: v1.33.3+k3s1
Type: Single Node Cluster
Mode: Embedded SQLite (etcd)
```

**Composants intégrés :**
- **API Server** : Point d'entrée Kubernetes (port 6443)
- **Controller Manager** : Gestion des ressources
- **Scheduler** : Placement des pods
- **etcd** : Base de données clé-valeur (embedded)
- **Kubelet** : Agent sur le nœud
- **Container Runtime** : containerd

**Configuration spécifique :**
- **Kubeconfig mode** : 644 (accessible utilisateur)
- **Data Directory** : `/var/lib/rancher/k3s/`
- **Service Account** : Enabled
- **Network Plugin** : Flannel (par défaut)

### 2. **Traefik (Ingress Controller)**

```yaml
Version: Bundled with K3s
Namespace: kube-system
Service: LoadBalancer (NodePort)
```

**Fonctionnalités :**
- **Reverse Proxy** : Routage des requêtes HTTP/HTTPS
- **Load Balancer** : Distribution de charge
- **SSL Termination** : Gestion des certificats TLS
- **Middleware** : Redirections, authentification, rate limiting
- **Dashboard** : Interface web (optionnel)

**Configuration :**
- **HTTP Port** : 80 → 32170 (NodePort)
- **HTTPS Port** : 443 → 31931 (NodePort)
- **Dashboard** : 8080 (disabled by default)
- **Config** : Auto-découverte via annotations

### 3. **cert-manager**

```yaml
Version: v1.13.1
Namespace: cert-manager
Chart: jetstack/cert-manager
```

**Composants :**
- **cert-manager-controller** : Gestion des certificats
- **cert-manager-webhook** : Validation admission
- **cert-manager-cainjector** : Injection CA

**ClusterIssuers configurés :**
```yaml
letsencrypt-staging:
  server: https://acme-staging-v02.api.letsencrypt.org/directory
  solver: HTTP-01 (Traefik)
  
letsencrypt-prod:
  server: https://acme-v02.api.letsencrypt.org/directory
  solver: HTTP-01 (Traefik)
```

### 4. **FluxCD GitOps**

```yaml
Version: 2.6.4
Namespace: flux-system
Components: 6 controllers
```

**Controllers actifs :**
- **source-controller** : Git/Helm repositories
- **kustomize-controller** : Kustomization resources  
- **helm-controller** : Helm releases
- **notification-controller** : Alerts et webhooks
- **image-reflector-controller** : Scan d'images
- **image-automation-controller** : Updates automatiques

**Configuration :**
```yaml
Git Repository: team-mercurious/k3s-gitops
Branch: main
Path: ./clusters/vps
Interval: 1m (scan Git)
Reconciliation: 10m (apply changes)
```

## 📊 Monitoring Stack

### 5. **Prometheus**

```yaml
Version: kube-prometheus-stack
Namespace: monitoring
Storage: 10Gi PVC
Retention: 7 days
```

**Métriques collectées :**
- **Node metrics** : CPU, RAM, disk, network
- **Kubernetes metrics** : Pods, services, ingress
- **Application metrics** : Custom metrics via /metrics
- **Traefik metrics** : Request rates, response times

**Targets automatiques :**
- Kubernetes API server
- Kubelet et cAdvisor
- Node exporter
- Applications avec annotations

### 6. **Grafana**

```yaml
Version: Bundled with Prometheus stack
Namespace: monitoring
Admin: admin / admin123
Storage: 5Gi PVC
```

**Dashboards préinstallés :**
- **Kubernetes Cluster** : Vue d'ensemble du cluster
- **Node Exporter** : Métriques système
- **Traefik** : Proxy metrics
- **Applications** : Custom dashboards

**Data Sources :**
- **Prometheus** : Métriques principales
- **Loki** : Logs (si configuré)

### 7. **Kafka (Strimzi)**

```yaml
Version: Strimzi Operator
Namespace: kafka
Cluster: my-cluster
Mode: dual-role (single node)
```

**Architecture :**
```yaml
my-cluster-dual-role-0:
  Roles: [broker, controller]
  Storage: Persistent (local-path)
  Authentication: SASL/SCRAM-SHA-512
  
my-cluster-entity-operator:
  User Management: KafkaUser CRD
  Topic Management: KafkaTopic CRD
```

**Topics configurés :**
- `travel-generation.progress`
- `travel-generation.completed`
- `travel-enrichment.progress`
- `travel-enrichment.completed`
- `travel-proposal.progress`
- `travel-proposal.completed`

**Users :**
- `app-client` : Credentials pour les applications

## 🚀 Applications

### 8. **API Gateway**

```yaml
Image: ghcr.io/team-mercurious/api-gateway:latest
Namespace: app
Replicas: 2 (HPA enabled)
Port: 3000
```

**Configuration :**
- **Framework** : Nest.js
- **Database** : MongoDB (externe)
- **Cache** : Redis (externe)
- **Message Queue** : Kafka
- **Authentication** : Better Auth

**Resources :**
```yaml
requests:
  memory: 256Mi
  cpu: 100m
limits:
  memory: 512Mi
  cpu: 500m
```

**Health Checks :**
- **Startup Probe** : `/` (30 failures max)
- **Readiness Probe** : `/` (10s interval)
- **Liveness Probe** : `/` (30s interval)

### 9. **Microservices**

**api-generation :**
```yaml
Purpose: Génération d'itinéraires de voyage
Kafka Topics: travel-generation.*
Status: CrashLoopBackOff (à débugger)
```

**api-enrichment :**
```yaml
Purpose: Enrichissement des données de voyage
Kafka Topics: travel-enrichment.*
Status: CrashLoopBackOff (à débugger)
```

## 🔐 Security Components

### 10. **SOPS + age**

```yaml
SOPS Version: 3.8.1
age Version: 1.1.1
Public Key: age1e3z2qzqmxrhnp9ar07xs60qhwgaxaz8tn00464qkttkny4jn6gwsp5uavd
```

**Secrets chiffrés :**
- `secret-kafka.sops.yaml` : Credentials Kafka
- Autres secrets d'application

**FluxCD Integration :**
- Secret `sops-age` dans namespace `flux-system`
- Decryption automatique par FluxCD

### 11. **System Security**

**UFW Firewall :**
```yaml
Status: active
Default: deny incoming, allow outgoing
Open Ports:
  - 22/tcp (SSH)
  - 80/tcp (HTTP)
  - 443/tcp (HTTPS)
  - 6443/tcp (K3s API)
```

**fail2ban :**
```yaml
Status: active
Jails: sshd
Ban Duration: 10m (default)
Max Retries: 5
```

**SSH Configuration :**
```yaml
Port: 22
Authentication: Key-based only
PermitRootLogin: no
PasswordAuthentication: no
```

## 📦 Storage

### 12. **local-path-provisioner**

```yaml
Default Storage Class: local-path
Path: /opt/local-path-provisioner
Mode: WaitForFirstConsumer
```

**Persistent Volumes créés :**
- Prometheus data (10Gi)
- Grafana data (5Gi)
- Kafka data (automatic)

## 🌐 Network Architecture

### Ports et Services

```yaml
External (VPS):
  22: SSH
  80: HTTP (Traefik) → 32170
  443: HTTPS (Traefik) → 31931
  6443: K3s API Server

Internal (Cluster):
  10.43.0.0/16: ClusterIP range
  10.42.0.0/16: Pod network (Flannel)
  
Services:
  traefik: 10.43.137.167:80/443
  api-gateway: 10.43.193.170:80
  kafka-bootstrap: 9092 (internal)
  prometheus: 9090 (internal)
  grafana: 3000 (internal)
```

## 🔄 Data Flow

### Request Flow
```
Internet → UFW:443 → Traefik:443 → cert-manager (SSL) 
         → Traefik routing → Service → Pod
```

### Application Communication
```
API Gateway ←→ Kafka ←→ Microservices
     ↓
  MongoDB (external)
     ↓  
  Redis (external)
```

### Monitoring Flow
```
Applications → Prometheus → Grafana
     ↓
  Node Exporter → Metrics → Dashboards
     ↓
  Logs → stdout → kubectl logs
```