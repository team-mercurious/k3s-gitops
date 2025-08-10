# Monitoring Stack (Prometheus + Grafana)

## 📖 Overview

Le stack de monitoring est basé sur **kube-prometheus-stack**, une collection d'outils cloud-native pour la surveillance des clusters Kubernetes et des applications.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Data Sources  │    │   Collection    │    │  Visualization  │
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   Apps    │  │───▶│  │Prometheus │  │───▶│  │  Grafana  │  │
│  │ /metrics  │  │    │  │  Server   │  │    │  │Dashboard  │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   Node    │  │───▶│  │Prometheus │  │───▶│  │AlertManger│  │
│  │ Exporter  │  │    │  │   Rules   │  │    │  │   (SMTP)  │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │                 │
│  │ Kubernetes│  │───▶│  │   kube-   │  │    │                 │
│  │ API/etcd  │  │    │  │   state   │  │    │                 │
│  └───────────┘  │    │  │ metrics   │  │    │                 │
│                 │    │  └───────────┘  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Installation

### Via Helm (méthode utilisée)
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=5Gi
```

## 📊 Prometheus

### Configuration
```yaml
Version: v2.48.0
Namespace: monitoring
Retention: 7 days
Storage: 10Gi PVC
Scrape Interval: 30s
Evaluation Interval: 30s
```

### Targets surveillés
```yaml
# Découverte automatique via ServiceMonitor/PodMonitor
Targets:
  - kubernetes-apiservers
  - kubernetes-nodes
  - kubernetes-nodes-cadvisor
  - kubernetes-service-endpoints
  - kubernetes-services
  - kubernetes-pods
  - prometheus-node-exporter
  - kube-state-metrics
  - prometheus-operator
  - grafana
  - traefik (si activé)
```

### Métriques collectées
```yaml
System Metrics:
  - CPU: node_cpu_seconds_total
  - Memory: node_memory_*
  - Disk: node_disk_*
  - Network: node_network_*
  
Kubernetes Metrics:
  - Pods: kube_pod_*
  - Nodes: kube_node_*
  - Services: kube_service_*
  - Deployments: kube_deployment_*
  
Container Metrics:
  - CPU: container_cpu_usage_seconds_total
  - Memory: container_memory_*
  - Network: container_network_*
```

### PromQL Queries utiles
```promql
# CPU utilisation par node
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory utilisation par node  
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pods par namespace
count by(namespace) (kube_pod_info)

# Request rate par service
sum(rate(http_requests_total[5m])) by(service)

# Top 10 pods CPU
topk(10, sum(rate(container_cpu_usage_seconds_total[5m])) by(pod))
```

## 📈 Grafana

### Configuration
```yaml
Version: 10.2.0
Admin User: admin
Admin Password: admin123
Namespace: monitoring
Storage: 5Gi PVC
Service Port: 3000
```

### Accès
```bash
# Port-forward vers Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

# Puis ouvrir : http://localhost:3000
# Login: admin / admin123
```

### Dashboards pré-installés
```yaml
Kubernetes Dashboards:
  - "Kubernetes / Compute Resources / Cluster"
  - "Kubernetes / Compute Resources / Namespace (Pods)"
  - "Kubernetes / Compute Resources / Node (Pods)"
  - "Kubernetes / Compute Resources / Pod"
  - "Kubernetes / Networking / Cluster"
  - "Kubernetes / Networking / Namespace (Pods)"

Node Dashboards:
  - "Node Exporter / Nodes"
  - "Node Exporter / USE Method / Node"
  - "Node Exporter / USE Method / Cluster"

Application Dashboards:
  - "Prometheus / Overview"
  - "Grafana / Overview"
```

### Data Sources configurées
```yaml
Prometheus:
  Name: Prometheus
  Type: prometheus
  URL: http://kube-prometheus-stack-prometheus:9090
  Access: Server (default)
  Default: true
```

### Dashboards personnalisés
```json
{
  "dashboard": {
    "title": "Application Metrics",
    "panels": [
      {
        "title": "API Gateway Requests",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=\"api-gateway\"}[5m]))",
            "legendFormat": "RPS"
          }
        ]
      }
    ]
  }
}
```

## 🔔 AlertManager

### Configuration
```yaml
Version: v0.26.0
Namespace: monitoring  
Replicas: 1
Storage: Ephemeral
Config: Via AlertManagerConfig CRD
```

### Configuration des alertes
```yaml
# Exemple d'alerte critique
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: monitoring
spec:
  groups:
  - name: application
    rules:
    - alert: HighMemoryUsage
      expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage detected"
        description: "Memory usage is above 90% for more than 5 minutes"
        
    - alert: PodCrashLooping
      expr: kube_pod_container_status_restarts_total > 5
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} has restarted more than 5 times"
```

### Configuration notifications (exemple Slack)
```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: slack-config
  namespace: monitoring
spec:
  route:
    groupBy: ['alertname']
    groupWait: 10s
    groupInterval: 10s
    repeatInterval: 1h
    receiver: 'slack-notifications'
  receivers:
  - name: 'slack-notifications'
    slackConfigs:
    - apiURL: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
      channel: '#alerts'
      title: 'Kubernetes Alert'
      text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## 📊 Node Exporter

### Métriques système collectées
```yaml
CPU:
  - node_cpu_seconds_total
  - node_load1, node_load5, node_load15
  
Memory:
  - node_memory_MemTotal_bytes
  - node_memory_MemFree_bytes  
  - node_memory_MemAvailable_bytes
  - node_memory_Buffers_bytes
  - node_memory_Cached_bytes
  
Disk:
  - node_disk_io_time_seconds_total
  - node_disk_reads_completed_total
  - node_disk_writes_completed_total
  - node_filesystem_size_bytes
  - node_filesystem_free_bytes
  
Network:
  - node_network_receive_bytes_total
  - node_network_transmit_bytes_total
  - node_network_receive_packets_total
  - node_network_transmit_packets_total
```

## 🔧 Kube-State-Metrics

### Métriques Kubernetes
```yaml
Pods:
  - kube_pod_info
  - kube_pod_status_phase
  - kube_pod_container_status_restarts_total
  
Deployments:
  - kube_deployment_status_replicas
  - kube_deployment_status_replicas_available
  
Services:
  - kube_service_info
  - kube_service_spec_type
  
Nodes:
  - kube_node_info
  - kube_node_status_condition
  - kube_node_status_capacity
```

## 🛠️ Commandes utiles

### Prometheus
```bash
# Port-forward vers Prometheus
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090

# Vérifier les targets
curl http://localhost:9090/api/v1/targets

# Query API
curl "http://localhost:9090/api/v1/query?query=up"

# Configuration reload
curl -X POST http://localhost:9090/-/reload
```

### Grafana
```bash
# Port-forward vers Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

# Reset admin password
kubectl -n monitoring patch secret kube-prometheus-stack-grafana \
  -p '{"data":{"admin-password":"'$(echo -n "newpassword" | base64)'"}}'

# Restart Grafana pod
kubectl -n monitoring rollout restart deployment kube-prometheus-stack-grafana
```

### AlertManager
```bash
# Port-forward vers AlertManager
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093

# Vérifier la configuration
curl http://localhost:9093/api/v1/status/config

# Lister les alertes actives
curl http://localhost:9093/api/v1/alerts
```

## 🔍 Troubleshooting

### Problèmes courants

**1. Prometheus targets down**
```bash
# Vérifier les ServiceMonitors
kubectl get servicemonitors -A

# Vérifier les endpoints
kubectl get endpoints -n monitoring

# Logs Prometheus
kubectl -n monitoring logs deployment/kube-prometheus-stack-prometheus
```

**2. Grafana dashboard vide**
```bash
# Vérifier la datasource
kubectl -n monitoring exec deployment/kube-prometheus-stack-grafana -- \
  curl http://localhost:3000/api/datasources

# Tester la connectivité Prometheus
kubectl -n monitoring exec deployment/kube-prometheus-stack-grafana -- \
  curl http://kube-prometheus-stack-prometheus:9090/api/v1/targets
```

**3. Métriques manquantes**
```bash
# Vérifier les labels des services
kubectl get svc -A --show-labels | grep monitoring

# Vérifier les ServiceMonitors
kubectl describe servicemonitor -n monitoring

# Test de connectivité
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://service-name:port/metrics
```

## 📈 Performance et optimisation

### Prometheus tuning
```yaml
# Configuration avancée
spec:
  prometheus:
    prometheusSpec:
      retention: 15d
      retentionSize: 50GB
      resources:
        requests:
          memory: 2Gi
          cpu: 500m
        limits:
          memory: 4Gi
          cpu: 2000m
      storageSpec:
        volumeClaimTemplate:
          spec:
            resources:
              requests:
                storage: 50Gi
```

### Réduction de cardinalité
```yaml
# Limiter les métriques collectées
metricRelabelings:
- sourceLabels: [__name__]
  regex: 'container_network_.*|container_fs_.*'
  action: drop

# Sampling des métriques
scrapeInterval: 60s  # Au lieu de 30s par défaut
```

## 📊 Métriques business

### Exposition métriques custom
```javascript
// Node.js avec prometheus-client
const promClient = require('prom-client');

// Counter pour les requêtes
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

// Histogram pour la latence  
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

// Endpoint metrics
app.get('/metrics', (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(promClient.register.metrics());
});
```

### ServiceMonitor pour apps custom
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: api-gateway
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: api-gateway
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
```

## 🔗 Resources

- **Prometheus** : https://prometheus.io/docs/
- **Grafana** : https://grafana.com/docs/
- **kube-prometheus** : https://github.com/prometheus-operator/kube-prometheus
- **PromQL** : https://prometheus.io/docs/prometheus/latest/querying/