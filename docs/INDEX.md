# Index complet de la documentation

## 📚 Vue d'ensemble

Cette documentation couvre l'infrastructure complète K3s avec GitOps déployée sur le VPS OVH. 

**Infrastructure** : 1 VPS Ubuntu 22.04 (37.59.98.241)  
**Applications** : 3 microservices + monitoring + GitOps  
**Domaine** : gotravelyzer.com  
**Repository GitOps** : https://github.com/team-mercurious/k3s-gitops

## 🏗️ Architecture

| Document | Description |
|----------|-------------|
| [Vue d'ensemble](./architecture/overview.md) | Architecture générale, diagrammes, principes |
| [Composants](./architecture/components.md) | Détail technique de chaque composant |

**Points clés :**
- K3s single-node avec Traefik intégré
- FluxCD pour GitOps avec automation d'images  
- Monitoring Prometheus/Grafana
- Secrets chiffrés avec SOPS/age
- SSL automatique avec Let's Encrypt

## 🛠️ Outils déployés

| Outil | Version | Namespace | Description | Doc |
|-------|---------|-----------|-------------|-----|
| **K3s** | v1.33.3+k3s1 | - | Orchestrateur Kubernetes | [📖](./tools/k3s.md) |
| **Traefik** | Bundled | kube-system | Reverse proxy / Ingress | [📖](./tools/traefik.md) |
| **FluxCD** | 2.6.4 | flux-system | GitOps automation | [📖](./tools/fluxcd.md) |
| **cert-manager** | v1.13.1 | cert-manager | Gestion SSL Let's Encrypt | [📖](./tools/cert-manager.md) |
| **Prometheus** | 2.48.0 | monitoring | Métriques et alerting | [📖](./tools/monitoring.md) |
| **Grafana** | 10.2.0 | monitoring | Visualisation dashboards | [📖](./tools/monitoring.md) |
| **Kafka** | Strimzi | kafka | Message broker | [📖](./tools/kafka.md) |
| **SOPS/age** | 3.8.1/1.1.1 | - | Chiffrement secrets | [📖](./tools/secrets.md) |

### Outils système

| Outil | Status | Description | Doc |
|-------|--------|-------------|-----|
| **UFW** | ✅ Active | Firewall (22,80,443,6443) | [📖](./tools/system.md) |
| **fail2ban** | ✅ Active | Protection SSH brute-force | [📖](./tools/system.md) |
| **unattended-upgrades** | ✅ Active | Mises à jour sécurité auto | [📖](./tools/system.md) |
| **SSH** | ✅ Active | Accès sécurisé (clés uniquement) | [📖](./tools/system.md) |

## 📖 Guides pratiques

| Guide | Objectif | Temps estimé |
|-------|----------|--------------|
| [Installation](./guides/installation.md) | Installer l'infrastructure complète | 1h30-2h |
| [GitOps](./guides/gitops.md) | Workflow complet de déploiement | 30min |
| [CI/CD](./guides/cicd.md) | Pipeline build → deploy | 45min |
| [Monitoring](./guides/monitoring.md) | Surveillance et alerting | 30min |
| [Secrets](./guides/secrets.md) | Gestion SOPS/age | 20min |
| [SSL/TLS](./guides/ssl.md) | Certificats et domaines | 15min |

## 🚀 Quick Start

### Pour démarrer rapidement
```bash
# 1. Installation automatisée
./scripts/bootstrap.sh

# 2. Configuration GitOps
flux bootstrap github --owner=team-mercurious --repository=k3s-gitops

# 3. Accès monitoring
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

### URLs d'accès
- **API Gateway** : https://api2.gotravelyzer.com
- **Grafana** : Port-forward 3000 (admin/admin123)
- **Prometheus** : Port-forward 9090
- **GitOps Repo** : https://github.com/team-mercurious/k3s-gitops

## 📊 Status actuel

### Cluster Kubernetes
```yaml
Nœuds: 1 (vps-6227e9e1)  
Status: Ready ✅
Pods système: 18/18 Running ✅
Namespaces: 7 (kube-system, flux-system, monitoring, cert-manager, kafka, app, default)
```

### Applications
```yaml
api-gateway: 1/1 Running ✅
api-generation: 0/1 CrashLoopBackOff ❌ (à débugger)
api-enrichment: 0/1 CrashLoopBackOff ❌ (à débugger)
kafka: 3/3 Running ✅
monitoring: 6/6 Running ✅
```

### Automation GitOps
```yaml
FluxCD: 6/6 controllers Running ✅
Git Sync: Actif (1min) ✅
Image Scan: Actif (1min) ✅
Auto Deploy: Configuré ✅
SOPS Decrypt: Fonctionnel ✅
```

## 🔧 Maintenance

### Tâches quotidiennes
- Vérifier status cluster : `kubectl get nodes,pods -A`
- Consulter logs : `kubectl logs -n app deployment/api-gateway`
- Monitoring FluxCD : `flux get all`

### Tâches hebdomadaires  
- Updates système : `sudo apt update && apt list --upgradable`
- Backup secrets : `cp age.agekey ~/backup-$(date +%Y%m%d).agekey`
- Vérifier métriques : Grafana dashboards

### Tâches mensuelles
- Rotation logs : `journalctl --vacuum-time=30d`
- Cleanup Docker : `k3s crictl system prune -a`
- Review security : `sudo ufw status` + `sudo fail2ban-client status`

## 🚨 Troubleshooting

### Problèmes fréquents

| Symptôme | Cause probable | Solution | Doc |
|----------|----------------|----------|-----|
| Pod CrashLoopBackOff | Config/secrets manquants | Check env vars et logs | [🔍](./troubleshooting/common-issues.md) |
| FluxCD not syncing | Git access ou SOPS | Vérifier tokens et clés | [🔍](./troubleshooting/debug.md) |
| Certificate error | Let's Encrypt rate limit | Utiliser staging issuer | [🔍](./troubleshooting/ssl-issues.md) |
| Out of disk space | Logs ou images | Cleanup avec crictl | [🔍](./troubleshooting/storage.md) |

### Commandes de debug
```bash
# Status général
kubectl get all -A
flux get all
systemctl status k3s

# Logs détaillés
kubectl logs -n flux-system deploy/kustomize-controller
journalctl -u k3s -n 50
sudo fail2ban-client status sshd

# Resources système
df -h
free -h
top
```

## 🔐 Sécurité

### Mesures en place
- ✅ **Firewall UFW** : Ports limités (22,80,443,6443)  
- ✅ **fail2ban** : Protection brute-force SSH
- ✅ **SSH keys only** : Pas d'authentification par mot de passe
- ✅ **TLS everywhere** : HTTPS forcé avec Let's Encrypt
- ✅ **Secrets chiffrés** : SOPS/age dans Git
- ✅ **RBAC Kubernetes** : Permissions minimales
- ✅ **Updates auto** : Sécurité système

### Audits recommandés
- Vérifier les connexions SSH : `grep "Accepted" /var/log/auth.log`
- Lister les processus root : `ps aux | grep root`
- Vérifier les certificats : `kubectl get certificates -A`

## 📈 Métriques importantes

### Prometheus queries utiles
```promql
# CPU utilization
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory utilization  
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pods par namespace
count by(namespace) (kube_pod_info)

# FluxCD reconciliation errors
gotk_reconcile_condition{type="Ready", status="False"}
```

### Dashboards Grafana
- **Kubernetes Cluster Overview** : Vue d'ensemble du cluster
- **Node Exporter Full** : Métriques système détaillées  
- **Application Metrics** : Métriques custom des apps
- **Traefik Dashboard** : Métriques proxy et ingress

## 📝 Changelog

### 2025-08-10 - Déploiement initial
- ✅ Infrastructure K3s complète
- ✅ GitOps FluxCD configuré
- ✅ Monitoring Prometheus/Grafana
- ✅ SSL Let's Encrypt automatique
- ✅ Applications api-gateway déployées
- ✅ Secrets SOPS/age configurés
- ✅ Documentation complète

## 🤝 Support

### Contacts
- **Admin système** : Nathan Bardi (devw.nbardi@gmail.com)
- **Repo GitOps** : https://github.com/team-mercurious/k3s-gitops
- **Organisation** : https://github.com/team-mercurious

### Resources externes
- **K3s** : https://k3s.io/
- **FluxCD** : https://fluxcd.io/
- **Prometheus** : https://prometheus.io/
- **Grafana** : https://grafana.com/

---

*Documentation générée automatiquement le 2025-08-10*  
*Dernière mise à jour : Infrastructure v1.0*