# 📊 Monitoring et Opérations

Guide des opérations courantes et du monitoring pour l'infrastructure Mercurious.

## 🎯 Vue d'ensemble

Cette documentation couvre :
- Monitoring des services et déploiements
- Commandes d'opérations courantes  
- Diagnostic et résolution de problèmes
- Métriques et alertes

## 🔍 Monitoring des services

### Statut global

```bash
# Vue d'ensemble de tous les services
kubectl get pods -n app
kubectl get deployments -n app
kubectl get services -n app
kubectl get ingress -n app

# Statut des namespaces critiques
kubectl get pods -n kafka
kubectl get pods -n flux-system
```

### Monitoring par service

#### API Gateway

```bash
# Statut du deployment
kubectl get deployment api-gateway -n app
kubectl describe deployment api-gateway -n app

# Logs en temps réel
kubectl logs -n app -l app=api-gateway -f --tail=50

# Test de connectivité
curl -k https://api2.gotravelyzer.com/
curl -k https://api2.gotravelyzer.com/health
```

#### API Enrichment (Microservice Kafka)

```bash
# Statut du service
kubectl get pods -n app -l app=api-enrichment
kubectl logs -n app -l app=api-enrichment --tail=50

# Vérifier la connexion Kafka
kubectl logs -n app -l app=api-enrichment | grep -i "consumer.*group"
kubectl logs -n app -l app=api-enrichment | grep -i "successfully started"
```

#### API Generation (Microservice Kafka)

```bash
# Statut du service  
kubectl get pods -n app -l app=api-generation
kubectl logs -n app -l app=api-generation --tail=50

# Vérifier les topics assignés
kubectl logs -n app -l app=api-generation | grep -i "memberAssignment"
```

### Monitoring Kafka

```bash
# Cluster Kafka
kubectl get kafka -n kafka
kubectl get pods -n kafka
kubectl describe kafka my-cluster -n kafka

# Utilisateurs Kafka
kubectl get kafkauser -n kafka
kubectl describe kafkauser app-client -n kafka

# Logs Kafka
kubectl logs -n kafka my-cluster-dual-role-0 --tail=50
kubectl logs -n kafka -l app=strimzi-cluster-operator --tail=20
```

### Monitoring FluxCD

```bash
# Controllers Flux
kubectl get pods -n flux-system
kubectl logs -n flux-system -l app=source-controller --tail=20
kubectl logs -n flux-system -l app=image-reflector-controller --tail=20

# Repositories et policies d'images
kubectl get imagerepository -n flux-system
kubectl get imagepolicy -n flux-system
kubectl describe imagerepository api-gateway -n flux-system

# Automation de déploiement
kubectl get cronjob -n app
kubectl get jobs -n app
kubectl logs -n app -l job-name --tail=10
```

## 🛠️ Opérations courantes

### Redémarrage des services

```bash
# Redémarrage d'un service spécifique
kubectl rollout restart deployment/api-gateway -n app
kubectl rollout restart deployment/api-enrichment -n app  
kubectl rollout restart deployment/api-generation -n app

# Redémarrage de tous les services
kubectl rollout restart deployment -n app

# Vérification du rollout
kubectl rollout status deployment/api-gateway -n app
```

### Mise à jour manuelle des images

```bash
# Forcer le déploiement avec le script automatique
/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/auto-deploy.sh

# Forcer un redéploiement complet
/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/force-deploy.sh

# Mise à jour manuelle d'une image spécifique
kubectl patch deployment api-gateway -n app -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","image":"ghcr.io/team-mercurious/api-gateway:sha-NOUVEAU_SHA"}]}}}}'
```

### Gestion des secrets

```bash
# Lister les secrets
kubectl get secrets -n app
kubectl get secrets -n flux-system

# Décoder un secret
kubectl get secret kafka-sasl -n app -o jsonpath='{.data.username}' | base64 -d
kubectl get secret kafka-sasl -n app -o jsonpath='{.data.password}' | base64 -d

# Mettre à jour un secret
kubectl create secret generic kafka-sasl -n app \
  --from-literal=username=app-client \
  --from-literal=password=NOUVEAU_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Scaling des services

```bash
# Scaling horizontal
kubectl scale deployment api-gateway -n app --replicas=3
kubectl scale deployment api-enrichment -n app --replicas=2

# Vérifier le scaling
kubectl get deployment -n app
kubectl get hpa -n app  # Si HPA configuré

# Auto-scaling (si configuré)
kubectl describe hpa api-gateway -n app
```

## 📈 Métriques et monitoring

### Métriques des ressources

```bash
# Utilisation CPU/RAM par pod
kubectl top pods -n app
kubectl top nodes

# Détails des ressources par deployment
kubectl describe deployment api-gateway -n app | grep -A 10 "Resource"
kubectl describe pod -n app -l app=api-gateway | grep -A 5 "Requests\|Limits"
```

### Métriques Kafka

```bash
# Topics et partitions
kubectl exec -n kafka my-cluster-dual-role-0 -- \
  kafka-topics --bootstrap-server localhost:9092 --list

# Groupes de consommateurs
kubectl exec -n kafka my-cluster-dual-role-0 -- \
  kafka-consumer-groups --bootstrap-server localhost:9092 --list

# Lag des consommateurs
kubectl exec -n kafka my-cluster-dual-role-0 -- \
  kafka-consumer-groups --bootstrap-server localhost:9092 \
  --describe --group enrichment-consumer-server
```

### Métriques de déploiement

```bash
# Historique des déploiements
kubectl rollout history deployment/api-gateway -n app

# Temps de déploiement
kubectl get events -n app --sort-by='.firstTimestamp' | grep -i deployment

# Images utilisées
kubectl get pods -n app -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u
```

## 🚨 Alertes et diagnostic

### Health checks et readiness

```bash
# Vérifier les health checks
kubectl describe pod -n app -l app=api-gateway | grep -A 10 "Conditions\|Events"

# Endpoints des services
kubectl get endpoints -n app
kubectl describe endpoints api-gateway -n app

# Test des services internes
kubectl run debug --rm -i --restart=Never --image=busybox -- \
  wget -qO- http://api-gateway.app.svc.cluster.local/health
```

### Diagnostic réseau

```bash
# Connectivité DNS
kubectl run debug --rm -i --restart=Never --image=busybox -- \
  nslookup api-gateway.app.svc.cluster.local

kubectl run debug --rm -i --restart=Never --image=busybox -- \
  nslookup my-cluster-kafka-bootstrap.kafka.svc.cluster.local

# Test de ports
kubectl run debug --rm -i --restart=Never --image=busybox -- \
  telnet api-gateway.app.svc.cluster.local 80
```

### Logs centralisés

```bash
# Logs par service avec timestamps
kubectl logs -n app -l app=api-gateway --timestamps=true --tail=100
kubectl logs -n app -l app=api-enrichment --timestamps=true --tail=100
kubectl logs -n app -l app=api-generation --timestamps=true --tail=100

# Logs d'erreurs uniquement
kubectl logs -n app -l app=api-gateway | grep -i error
kubectl logs -n app -l app=api-enrichment | grep -i "error\|warn\|fatal"

# Logs avec filtrage par timerange
kubectl logs -n app api-gateway-xxx --since=1h
kubectl logs -n app api-gateway-xxx --since-time='2025-08-11T08:00:00Z'
```

## 📊 Dashboard et visualisation

### Commandes de statut rapide

```bash
# Dashboard custom - statut global
cat << 'EOF' > /tmp/status.sh
#!/bin/bash
echo "=== STATUT GLOBAL ==="
echo "Pods en cours:"
kubectl get pods -n app --no-headers | awk '{print $1, $3}' | column -t

echo -e "\n=== SERVICES ==="
kubectl get svc -n app --no-headers | awk '{print $1, $2, $3}' | column -t

echo -e "\n=== IMAGES ACTUELLES ==="
kubectl get pods -n app -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u

echo -e "\n=== FLUX STATUS ==="
kubectl get imagerepository,imagepolicy -n flux-system --no-headers | awk '{print $1, $2}' | column -t

echo -e "\n=== CRONJOB AUTO-DEPLOY ==="
kubectl get cronjob,job -n app --no-headers | awk '{print $1, $2, $3}' | column -t
EOF

chmod +x /tmp/status.sh
/tmp/status.sh
```

### Monitoring en temps réel

```bash
# Watch des ressources critiques
watch -n 5 'kubectl get pods -n app'
watch -n 10 'kubectl get imagerepository -n flux-system'

# Tail des logs en temps réel
kubectl logs -n app -l app=api-gateway -f --tail=20 &
kubectl logs -n app -l job-name -f --tail=5 &
```

## ⚡ Scripts d'automatisation

### Script de health check complet

```bash
# /home/ubuntu/infrastructure/k3s-gitops-clone/scripts/health-check.sh
#!/bin/bash

echo "🏥 Health Check Global - $(date)"
echo "================================"

# Services status
echo "📊 Status des services:"
kubectl get deployment -n app -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,TOTAL:.status.replicas,IMAGE:.spec.template.spec.containers[0].image

# Kafka connectivity
echo -e "\n🔗 Connectivité Kafka:"
kubectl logs -n app -l app=api-enrichment --tail=5 | grep -q "successfully started" && echo "✅ Enrichment connecté" || echo "❌ Enrichment déconnecté"
kubectl logs -n app -l app=api-generation --tail=5 | grep -q "successfully started" && echo "✅ Generation connecté" || echo "❌ Generation déconnecté"

# FluxCD status  
echo -e "\n🔄 Status FluxCD:"
kubectl get imagerepository -n flux-system --no-headers | while read name scan tags; do
  echo "$name: $tags tags (scan: $scan)"
done

# Recent deployments
echo -e "\n🚀 Déploiements récents:"
kubectl get events -n app --field-selector reason=Scheduled --sort-by='.firstTimestamp' | tail -3

echo -e "\n✅ Health check terminé"
```

### Script de monitoring continu

```bash
# /home/ubuntu/infrastructure/k3s-gitops-clone/scripts/monitor.sh
#!/bin/bash

while true; do
    clear
    echo "📊 MONITORING DASHBOARD - $(date)"
    echo "================================="
    
    echo "🎯 Services Status:"
    kubectl get pods -n app --no-headers | awk '{print $1 "\t" $3 "\t" $4 "\t" $5}'
    
    echo -e "\n🔄 Dernière activité auto-deploy:"
    kubectl logs -n app -l job-name --tail=1 2>/dev/null || echo "Aucun job récent"
    
    echo -e "\n📈 Resource Usage:"
    kubectl top pods -n app --no-headers 2>/dev/null | awk '{print $1 "\t" $2 "\t" $3}' || echo "Metrics non disponibles"
    
    echo -e "\n⏳ Prochaine actualisation dans 30s (Ctrl+C pour arrêter)"
    sleep 30
done
```

## 🔔 Alerting

### Conditions d'alerte recommandées

#### Services critiques
- Pod crashant plus de 3 fois en 10 minutes
- Service inaccessible pendant plus de 2 minutes
- Déploiement bloqué pendant plus de 5 minutes

#### Kafka
- Connexions fermées répétées (> 5 en 5min)
- Lag consommateur > 1000 messages
- Rebalancing permanent (> 5 en 10min)

#### Infrastructure
- Usage CPU > 80% pendant 5 minutes
- Usage RAM > 90% pendant 2 minutes
- Disk usage > 85%

### Script d'alerte simple

```bash
# /home/ubuntu/infrastructure/k3s-gitops-clone/scripts/alert-check.sh
#!/bin/bash

ALERT=false

# Check pods en erreur
ERROR_PODS=$(kubectl get pods -n app --no-headers | grep -v "Running\|Completed" | wc -l)
if [ "$ERROR_PODS" -gt 0 ]; then
    echo "🚨 ALERT: $ERROR_PODS pods en erreur"
    kubectl get pods -n app | grep -v "Running\|Completed"
    ALERT=true
fi

# Check services non disponibles  
for service in api-gateway api-enrichment api-generation; do
    READY=$(kubectl get deployment $service -n app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$READY" -eq 0 ]; then
        echo "🚨 ALERT: Service $service non disponible"
        ALERT=true
    fi
done

if [ "$ALERT" = false ]; then
    echo "✅ Tous les services opérationnels"
fi
```

## 📝 Logs et audit

### Rétention des logs

```bash
# Logs des 24 dernières heures
kubectl logs -n app api-gateway-xxx --since=24h > logs/gateway-$(date +%Y%m%d).log

# Archivage automatique
mkdir -p /home/ubuntu/logs/$(date +%Y/%m)
kubectl logs -n app -l app=api-gateway --tail=1000 > /home/ubuntu/logs/$(date +%Y/%m)/gateway-$(date +%Y%m%d-%H%M).log
```

### Audit des déploiements

```bash
# Historique des changements d'images
kubectl rollout history deployment/api-gateway -n app --revision=1
kubectl rollout history deployment/api-gateway -n app --revision=2

# Events système
kubectl get events -n app --sort-by='.firstTimestamp' > /tmp/events-$(date +%Y%m%d).log
```

## ✅ Checklist opérationnelle quotidienne

- [ ] Vérifier le statut de tous les pods (`kubectl get pods -n app`)
- [ ] Contrôler les logs d'erreurs des dernières 24h
- [ ] Valider la connectivité des endpoints publics
- [ ] Vérifier le bon fonctionnement des CronJobs
- [ ] Contrôler l'état de FluxCD et des images
- [ ] Vérifier l'espace disque et les ressources
- [ ] Tester la chaîne de déploiement complète

## 📞 Procédures d'urgence

### Service down complet

1. Vérifier le statut : `kubectl get pods -n app`
2. Consulter les logs : `kubectl logs -n app -l app=SERVICE --tail=100`
3. Redémarrer le service : `kubectl rollout restart deployment/SERVICE -n app`
4. Si persistant : revenir à l'image précédente
5. Alerter l'équipe et documenter l'incident

### Problème Kafka

1. Vérifier le cluster : `kubectl get pods -n kafka`
2. Redémarrer les consumers : `kubectl rollout restart deployment -n app`  
3. Vérifier la connectivité réseau interne
4. Si persistant : redémarrer Kafka (avec précaution)

### Flux auto-deploy cassé

1. Déploiement manuel : `/home/ubuntu/infrastructure/k3s-gitops-clone/scripts/auto-deploy.sh`
2. Vérifier les ImageRepositories : `kubectl get imagerepository -n flux-system`
3. Forcer un scan : `kubectl annotate imagerepository SERVICE -n flux-system image.toolkit.fluxcd.io/reconcile=$(date +%s)`
4. Si persistant : redéployer le CronJob

**Documentation mise à jour le 11/08/2025** ✅