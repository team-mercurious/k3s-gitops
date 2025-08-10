# Architecture Overview

## 🏗️ Vue d'ensemble de l'infrastructure

L'infrastructure est basée sur une architecture cloud-native moderne avec les principes DevOps et GitOps.

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                               │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                    VPS Ubuntu 22.04                            │
│                 37.59.98.241 (OVH)                             │
├─────────────────────────────────────────────────────────────────┤
│                    Security Layer                               │
│  ┌─────────────┬──────────────┬─────────────────┬──────────────┐ │
│  │    UFW      │  fail2ban    │ unattended-     │    SSH       │ │
│  │  Firewall   │   (SSH)      │   upgrades      │   (port 22)  │ │
│  └─────────────┴──────────────┴─────────────────┴──────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                   Kubernetes Layer (K3s)                       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Control Plane                            │ │
│  │  ┌─────────────┬──────────────┬─────────────────────────────┐ │ │
│  │  │ API Server  │   etcd       │       Scheduler             │ │ │
│  │  │  (6443)     │ (embedded)   │                             │ │ │
│  │  └─────────────┴──────────────┴─────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                   Application Layer                             │
│  ┌─────────────────┬─────────────────┬─────────────────────────┐ │
│  │   Namespaces    │                 │                         │ │
│  │  ┌────────────┐ │  ┌────────────┐ │  ┌────────────────────┐ │ │
│  │  │kube-system │ │  │flux-system │ │  │    monitoring      │ │ │
│  │  │ - traefik  │ │  │ - fluxcd   │ │  │ - prometheus       │ │ │
│  │  │ - coredns  │ │  │ - sops     │ │  │ - grafana          │ │ │
│  │  └────────────┘ │  └────────────┘ │  │ - alertmanager     │ │ │
│  │                 │                 │  └────────────────────┘ │ │
│  │  ┌────────────┐ │  ┌────────────┐ │  ┌────────────────────┐ │ │
│  │  │cert-manager│ │  │    kafka   │ │  │         app        │ │ │
│  │  │ - issuer   │ │  │ - strimzi  │ │  │ - api-gateway      │ │ │
│  │  │ - certs    │ │  │ - cluster  │ │  │ - api-generation   │ │ │
│  │  └────────────┘ │  └────────────┘ │  │ - api-enrichment   │ │ │
│  │                 │                 │  └────────────────────┘ │ │
│  └─────────────────┴─────────────────┴─────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    Network Layer                                │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Traefik Ingress                          │ │
│  │  ┌──────────────┬────────────────┬───────────────────────┐  │ │
│  │  │   HTTP:80    │   HTTPS:443    │     Dashboard:8080    │  │ │
│  │  │ (redirect)   │  (TLS/SSL)     │    (if enabled)       │  │ │
│  │  └──────────────┴────────────────┴───────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    Storage Layer                                │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                local-path-provisioner                       │ │
│  │  ┌──────────────┬────────────────┬───────────────────────┐  │ │
│  │  │ Kafka Data   │ Monitoring     │   Application Logs    │  │ │
│  │  │ (/var/lib/)  │ (Prometheus)   │    (ephemeral)        │  │ │
│  │  └──────────────┴────────────────┴───────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 GitOps Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │    GitHub       │    │   GitHub        │
│                 │    │   Repositories  │    │   Container     │
│  ┌───────────┐  │    │                 │    │   Registry      │
│  │Code Push  │  │    │ ┌─────────────┐ │    │                 │
│  │   (main)  ├──┼────┼─┤   CI/CD     │ │    │ ┌─────────────┐ │
│  └───────────┘  │    │ │  Actions    ├─┼────┼─┤   GHCR      │ │
└─────────────────┘    │ └─────────────┘ │    │ │ Images      │ │
                       │                 │    │ └─────────────┘ │
┌─────────────────┐    │ ┌─────────────┐ │    └─────────────────┘
│   K3s Cluster   │    │ │ k3s-gitops  │ │              │
│                 │    │ │ Repository  │ │              │
│  ┌───────────┐  │    │ └─────────────┘ │              │
│  │  FluxCD   │  │    └─────────────────┘              │
│  │           ├──┼──────────────┐                       │
│  │ ┌───────┐ │  │              │                       │
│  │ │Image  │ │  │              ▼                       │
│  │ │Scan   ├─┼──┼────────────────────────────────────────┘
│  │ └───────┘ │  │
│  └───────────┘  │    ┌─────────────────┐
└─────────────────┘    │   Auto Update   │
                       │  & Deployment   │
                       └─────────────────┘
```

## 🏛️ Principles architecturaux

### 1. **Cloud Native**
- **Containerisation** : Toutes les applications dans des conteneurs
- **Orchestration** : Kubernetes (K3s) pour la gestion
- **Service Mesh** : Communication inter-services via Kafka
- **Observabilité** : Prometheus + Grafana + Logs

### 2. **GitOps**
- **Source of Truth** : Git repository pour toute la configuration
- **Automated Deployment** : FluxCD synchronise automatiquement
- **Rollback** : Revert Git commit = rollback application
- **Security** : SOPS pour le chiffrement des secrets

### 3. **Security-First**
- **Defense in Depth** : Sécurité multi-couches
- **Least Privilege** : Permissions minimales requises
- **Encryption** : TLS everywhere, secrets chiffrés
- **Monitoring** : Surveillance continue des menaces

### 4. **High Availability**
- **Self-Healing** : Kubernetes redémarre les pods défaillants
- **Load Balancing** : Traefik répartit la charge
- **Health Checks** : Probes pour vérifier la santé des apps
- **Horizontal Scaling** : HPA pour l'auto-scaling

## 📊 Métriques système

### Resources VPS
- **CPU** : Utilisé par K3s, apps, monitoring
- **RAM** : Distribution entre les composants
- **Storage** : Local path provisioner
- **Network** : 1Gbps OVH, Traefik ingress

### Composants critiques
- **K3s Control Plane** : Toujours actif
- **Traefik** : Point d'entrée unique
- **FluxCD** : Synchronisation continue
- **Kafka** : Message broker haute disponibilité

## 🔒 Sécurité

### Niveaux de sécurité
1. **Infrastructure** : UFW + fail2ban
2. **Network** : TLS/SSL + Ingress rules  
3. **Kubernetes** : RBAC + Network Policies
4. **Application** : Authentication + secrets management
5. **Data** : Encryption at rest + in transit

### Compliance
- **Secrets** : Jamais en plaintext dans Git
- **TLS** : Certificats automatiques Let's Encrypt
- **Access** : SSH key only, no password auth
- **Audit** : Tous les changements via Git commits