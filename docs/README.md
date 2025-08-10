# Infrastructure Documentation

Cette documentation couvre l'infrastructure complète K3s avec GitOps déployée sur le VPS.

## 📚 Structure de la documentation

### 🏗️ [Architecture](./architecture/)
- [Vue d'ensemble](./architecture/overview.md) - Architecture générale du système
- [Composants](./architecture/components.md) - Détail de chaque composant
- [Réseaux](./architecture/network.md) - Configuration réseau et sécurité
- [Flux de données](./architecture/data-flow.md) - Comment les données circulent

### 🛠️ [Outils](./tools/)
- [Kubernetes (K3s)](./tools/k3s.md) - Orchestrateur de conteneurs
- [FluxCD](./tools/fluxcd.md) - GitOps et déploiement continu
- [Traefik](./tools/traefik.md) - Reverse proxy et load balancer
- [cert-manager](./tools/cert-manager.md) - Gestion des certificats SSL
- [Prometheus/Grafana](./tools/monitoring.md) - Monitoring et métriques
- [Kafka](./tools/kafka.md) - Message broker
- [SOPS/age](./tools/secrets.md) - Chiffrement des secrets
- [Outils système](./tools/system.md) - fail2ban, ufw, etc.

### 📖 [Guides](./guides/)
- [Installation](./guides/installation.md) - Installation complète depuis zéro
- [GitOps](./guides/gitops.md) - Workflow GitOps complet
- [CI/CD](./guides/cicd.md) - Pipeline de déploiement
- [Monitoring](./guides/monitoring.md) - Surveillance et alerting
- [Secrets](./guides/secrets.md) - Gestion des secrets avec SOPS
- [SSL/TLS](./guides/ssl.md) - Configuration des certificats

### 🔧 [Operations](./operations/)
- [Maintenance](./operations/maintenance.md) - Tâches de maintenance
- [Backup](./operations/backup.md) - Stratégie de sauvegarde
- [Scaling](./operations/scaling.md) - Mise à l'échelle
- [Updates](./operations/updates.md) - Mises à jour système

### 🚨 [Troubleshooting](./troubleshooting/)
- [Common Issues](./troubleshooting/common-issues.md) - Problèmes fréquents
- [Logs](./troubleshooting/logs.md) - Où trouver les logs
- [Debug](./troubleshooting/debug.md) - Techniques de debug
- [Recovery](./troubleshooting/recovery.md) - Procédures de récupération

## 🚀 Quick Start

1. **Installation rapide** : `./scripts/bootstrap.sh`
2. **Configuration GitOps** : Voir [guides/gitops.md](./guides/gitops.md)
3. **Monitoring** : Voir [guides/monitoring.md](./guides/monitoring.md)
4. **Premier déploiement** : Voir [guides/cicd.md](./guides/cicd.md)

## 📊 Status du système

- **Cluster** : K3s v1.33.3+k3s1
- **Applications** : 3 microservices (api-gateway, api-generation, api-enrichment)
- **Monitoring** : Prometheus + Grafana
- **GitOps** : FluxCD avec automation d'images
- **SSL** : Let's Encrypt avec renouvellement automatique
- **Logs** : Promtail → Loki → Grafana

## 🔗 Liens utiles

- **GitHub GitOps** : https://github.com/team-mercurious/k3s-gitops
- **API Gateway** : https://api2.gotravelyzer.com
- **Grafana** : Port-forward via kubectl
- **Prometheus** : Port-forward via kubectl

---

*Documentation générée automatiquement - Dernière mise à jour : $(date)*