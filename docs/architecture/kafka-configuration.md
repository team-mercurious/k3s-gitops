# 🔧 Configuration Kafka

Documentation détaillée de la configuration Kafka pour les microservices Mercurious.

## 📋 Vue d'ensemble

Kafka sert de bus de messages central pour la communication entre les microservices :
- **api-gateway** : Producteur (publie des messages)
- **api-enrichment** : Consommateur (traite l'enrichissement)
- **api-generation** : Consommateur (génère les réponses)

## 🏗️ Architecture Kafka

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Gateway   │───▶│  Kafka Cluster   │───▶│  Enrichment     │
│   (Producer)    │    │                  │    │  (Consumer)     │
└─────────────────┘    │  ┌─────────────┐ │    └─────────────────┘
                       │  │   Topics    │ │           │
┌─────────────────┐    │  │             │ │           │
│   Generation    │◀───│  └─────────────┘ │           │
│   (Consumer)    │    └──────────────────┘           │
└─────────────────┘                                   │
         │                                            │
         └────────────── Kafka ◀─────────────────────┘
```

## 📦 Déploiement Kafka

### Cluster Strimzi

```yaml
# Kafka installé via Strimzi Operator
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: kafka
spec:
  kafka:
    version: 3.8.0
    replicas: 1
    storage:
      type: ephemeral
  zookeeper:
    replicas: 1
    storage:
      type: ephemeral
```

### Services Kafka

```bash
# Services exposés
my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092  # Bootstrap server
my-cluster-kafka-brokers.kafka.svc.cluster.local:9092    # Direct brokers
```

## 🔐 Sécurité et authentification

### SASL Configuration

```yaml
# Configuration SASL
mechanism: scram-sha-512
securityProtocol: SASL_PLAINTEXT
ssl: false  # Pas de SSL en interne K8s
```

### Utilisateur Kafka

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: app-client
  namespace: kafka
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
    - resource:
        type: topic
        name: "*"
      operation: All
```

### Secrets Kubernetes

```yaml
# Secret SASL
apiVersion: v1
kind: Secret
metadata:
  name: kafka-sasl
  namespace: app
data:
  username: YXBwLWNsaWVudA==  # app-client (base64)
  password: <PASSWORD_BASE64>

# ConfigMap
apiVersion: v1
kind: ConfigMap  
metadata:
  name: kafka-config
  namespace: app
data:
  brokers: "my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
  mechanism: "scram-sha-512"
  securityProtocol: "SASL_PLAINTEXT"
```

## 🎯 Configuration par service

### API Gateway (Producer)

```typescript
// Configuration ClientsModule
ClientsModule.register([
  {
    name: 'KAFKA_SERVICE',
    transport: Transport.KAFKA,
    options: {
      client: {
        brokers: (process.env.KAFKA_BROKERS || '').split(','),
        clientId: 'http-gateway',
        ssl: false,
        sasl: {
          mechanism: 'scram-sha-512',
          username: process.env.KAFKA_SASL_USERNAME,
          password: process.env.KAFKA_SASL_PASSWORD,
        },
        connectionTimeout: 30000,
        requestTimeout: 30000,
        retry: {
          initialRetryTime: 100,
          retries: 8
        }
      },
      consumer: { 
        groupId: process.env.KAFKA_GROUP_ID || 'gateway-group',
        sessionTimeout: 30000,
        heartbeatInterval: 3000
      },
    },
  },
])
```

### API Enrichment (Consumer)

```typescript
// Configuration ClientsModule
{
  transport: Transport.KAFKA,
  options: {
    client: {
      brokers: (process.env.KAFKA_BROKERS || '').split(','),
      ssl: false,
      sasl: {
        mechanism: 'scram-sha-512',
        username: process.env.KAFKA_SASL_USERNAME,
        password: process.env.KAFKA_SASL_PASSWORD,
      },
    },
    consumer: {
      groupId: 'enrichment-consumer',
      allowAutoTopicCreation: true,
    },
  },
}
```

### API Generation (Consumer)

```typescript
// Configuration ClientsModule
{
  transport: Transport.KAFKA,
  options: {
    client: {
      brokers: (process.env.KAFKA_BROKERS || '').split(','),
      ssl: false,
      sasl: {
        mechanism: 'scram-sha-512',
        username: process.env.KAFKA_SASL_USERNAME,
        password: process.env.KAFKA_SASL_PASSWORD,
      },
    },
    consumer: {
      groupId: 'generation-consumer',
      allowAutoTopicCreation: true,
    },
  },
}
```

## 📊 Topics et groupes de consommateurs

### Topics actifs

| Topic | Description | Producteur | Consommateur |
|-------|-------------|------------|--------------|
| `travel-enrichment.request` | Demandes d'enrichissement | api-gateway | api-enrichment |
| `travel-generation.request` | Demandes de génération | api-gateway | api-generation |
| `travel-proposal.request` | Propositions de voyage | api-gateway | api-generation |

### Groupes de consommateurs

| Groupe | Service | Partitions assignées |
|--------|---------|---------------------|
| `enrichment-consumer-server` | api-enrichment | travel-enrichment.request[0,1,2] |
| `generation-consumer-server` | api-generation | travel-generation.request[0,1,2], travel-proposal.request[0,1,2] |
| `gateway-group` | api-gateway | N/A (producteur) |

## 🔧 Variables d'environnement

### Variables communes (tous services)

```bash
# Brokers
KAFKA_BROKERS="my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
KAFKA_BOOTSTRAP_SERVERS="my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
KAFKA_BROKER="my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"

# Authentification SASL
KAFKA_SASL_MECHANISM="scram-sha-512"
KAFKA_MECHANISM="scram-sha-512"
KAFKA_SASL_USERNAME="app-client"
KAFKA_SASL_PASSWORD="<PASSWORD>"
KAFKA_USERNAME="app-client"
KAFKA_PASSWORD="<PASSWORD>"
KAFKA_SASL_ENABLED="true"

# SSL/TLS
KAFKA_SSL="false"
KAFKA_SECURITY_PROTOCOL="SASL_PLAINTEXT"

# Configuration
KAFKAJS_NO_PARTITIONER_WARNING="1"

# Timeouts et retry
KAFKA_RETRY_INITIAL_RETRY_TIME="100"
KAFKA_RETRY_RETRIES="8"
KAFKA_CONNECTION_TIMEOUT="30000"
KAFKA_REQUEST_TIMEOUT="30000"
```

### Variables spécifiques par service

```bash
# API Gateway
KAFKA_CLIENT_ID="http-gateway"
KAFKA_GROUP_ID="gateway-group"

# API Enrichment  
KAFKA_CLIENT_ID="enrichment-service"
KAFKA_GROUP_ID="enrichment-consumers"

# API Generation
KAFKA_CLIENT_ID="generation-service"
KAFKA_GROUP_ID="generation-consumers"
```

## 🎛️ Configuration Kubernetes

### Deployment (exemple api-enrichment)

```yaml
env:
# Configuration Kafka complète
- name: KAFKA_BROKERS
  value: "my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
- name: KAFKA_SASL_MECHANISM
  value: "scram-sha-512"
- name: KAFKA_SECURITY_PROTOCOL
  valueFrom:
    configMapKeyRef:
      name: kafka-config
      key: securityProtocol
- name: KAFKA_SASL_USERNAME
  valueFrom:
    secretKeyRef:
      name: kafka-sasl
      key: username
- name: KAFKA_SASL_PASSWORD
  valueFrom:
    secretKeyRef:
      name: kafka-sasl
      key: password
- name: KAFKA_SASL_ENABLED
  value: "true"
- name: KAFKA_SSL
  value: "false"
- name: KAFKA_GROUP_ID
  value: "enrichment-consumers"
- name: KAFKA_CLIENT_ID
  value: "enrichment-service"
```

## 🔍 Monitoring et troubleshooting

### Commandes utiles

```bash
# Vérifier le cluster Kafka
kubectl get kafka -n kafka
kubectl get pods -n kafka

# Vérifier les utilisateurs Kafka
kubectl get kafkauser -n kafka

# Tester la connectivité
kubectl run kafka-test --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-3.8.0 \
  -- bash -c "kafka-console-producer --bootstrap-server \
  my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --topic test-topic"

# Logs des services
kubectl logs -n app -l app=api-enrichment --tail=50
kubectl logs -n app -l app=api-generation --tail=50
kubectl logs -n app -l app=api-gateway --tail=50
```

### Diagnostic des problèmes courants

#### Connexion fermée (`KafkaJSConnectionClosedError`)

**Symptômes :**
```
KafkaJSConnectionClosedError: Closed connection
  broker: 'my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092'
```

**Causes possibles :**
1. Problème d'authentification SASL
2. Kafka non démarré
3. Configuration réseau incorrecte
4. Timeout de connexion

**Solutions :**
```bash
# Vérifier le statut de Kafka
kubectl get pods -n kafka

# Vérifier l'utilisateur Kafka
kubectl get kafkauser app-client -n kafka

# Vérifier les secrets
kubectl get secret kafka-sasl -n app -o yaml
```

#### Rebalancing des groupes

**Symptômes :**
```
WARN [Runner] The group is rebalancing, re-joining
ERROR [Connection] Response Heartbeat: The group is rebalancing
```

**Cause :** Comportement normal lors de :
- Redémarrage de pods
- Ajout/suppression de consommateurs
- Changement de partition

**Action :** Aucune, le rebalancing se résout automatiquement

#### Health checks échoués

**Problème :** Microservices Kafka purs sans serveur HTTP

**Solution :** Health checks désactivés dans les deployments :
```yaml
# Pas de health checks HTTP pour les microservices Kafka
# livenessProbe: désactivé
# readinessProbe: désactivé  
# startupProbe: désactivé
```

## 📈 Performance et optimisation

### Paramètres de performance

```bash
# Timeouts optimisés
connectionTimeout: 30000ms
requestTimeout: 30000ms
sessionTimeout: 30000ms
heartbeatInterval: 3000ms

# Retry configuration
initialRetryTime: 100ms
retries: 8
```

### Monitoring des métriques

- **Latence des messages** : Temps entre production et consommation
- **Débit** : Messages par seconde
- **Lag des consommateurs** : Retard de traitement
- **Taux d'erreur** : Connexions échouées

## 🚨 Sécurité

### Authentification SASL-SCRAM
- **Mécanisme** : SCRAM-SHA-512 (sécurisé)
- **Utilisateur unique** : `app-client` pour tous les services
- **Permissions** : Accès complet aux topics (simplification dev)

### Chiffrement
- **SSL/TLS** : Désactivé (communication interne K8s)
- **Réseau** : Chiffré au niveau cluster (isolé)
- **Secrets** : Stockés dans Kubernetes Secrets (chiffrés etcd)

### Recommandations production
1. Activer SSL/TLS inter-brokers
2. Créer des utilisateurs spécifiques par service
3. Limiter les ACLs par topic/opération
4. Monitoring des accès et tentatives d'authentification

## ✅ Checklist de validation

Configuration fonctionnelle si :

- [ ] Cluster Kafka opérationnel (`kubectl get kafka -n kafka`)
- [ ] Utilisateur créé (`kubectl get kafkauser -n kafka`)
- [ ] Secrets configurés (`kubectl get secret kafka-sasl -n app`)
- [ ] Services connectés sans erreur (logs propres)
- [ ] Topics créés automatiquement
- [ ] Messages produits et consommés
- [ ] Groupes de consommateurs actifs
- [ ] Pas d'erreurs de connexion persistantes

**Configuration validée le 11/08/2025** ✅