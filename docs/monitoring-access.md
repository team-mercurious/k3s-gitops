# Guide d'Accès aux Interfaces de Monitoring Sécurisées

## Vue d'ensemble

Ce document décrit comment accéder aux interfaces de monitoring sécurisées déployées dans le cluster Kubernetes, incluant Prometheus et Grafana avec authentification et SSL.

## Interfaces Disponibles

### 🔐 Prometheus
- **URL**: https://prometheus.gotravelyzer.com
- **Authentification**: Basic Auth requis
- **Username**: `backlight`
- **Password**: `QR4xQ7QL5ppPhp`
- **Certificat SSL**: Let's Encrypt (automatique)

### 📊 Grafana
- **URL**: https://grafana.gotravelyzer.com
- **Authentification**: Interface Grafana native
- **Certificat SSL**: Let's Encrypt (automatique)
- **Credentials par défaut**: Vérifier le secret Kubernetes

## Configuration Technique

### Architecture de Sécurité

```
Internet → Traefik (SSL Termination) → Middleware Auth → Service Kubernetes
```

### Composants Déployés

1. **Ingress Controllers**:
   - `monitoring/prometheus-ingress.yaml`: Expose Prometheus avec middleware d'auth
   - `monitoring/grafana-ingress.yaml`: Expose Grafana avec SSL

2. **Authentification Prometheus**:
   - `monitoring/prometheus-auth-secret.yaml`: Credentials htpasswd encodés
   - `monitoring/prometheus-auth-middleware.yaml`: Middleware Traefik BasicAuth

3. **Certificats SSL**:
   - Gérés automatiquement par cert-manager
   - Issuer: `letsencrypt-prod`
   - Renouvellement automatique

## Gestion des Credentials

### Modification des Credentials Prometheus

1. Générer nouveau hash htpasswd:
```bash
htpasswd -nbB username password
```

2. Encoder en base64:
```bash
echo "username:$2y$10$..." | base64 -w 0
```

3. Mettre à jour le secret:
```yaml
# monitoring/prometheus-auth-secret.yaml
data:
  users: <hash_base64>
```

4. Appliquer les changements:
```bash
kubectl apply -f monitoring/prometheus-auth-secret.yaml
kubectl rollout restart deployment/traefik -n kube-system
```

### Récupération des Credentials Grafana

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-user}' | base64 -d
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

## Surveillance et Monitoring

### Vérification de l'État des Services

```bash
# Vérifier les pods de monitoring
kubectl get pods -n monitoring

# Vérifier les ingress
kubectl get ingress -n monitoring

# Vérifier les certificats
kubectl get certificates -n monitoring
```

### Logs de Débogage

```bash
# Logs Traefik (pour auth)
kubectl logs -n kube-system deployment/traefik

# Logs Prometheus
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0

# Logs Grafana
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana
```

## Dépannage

### Problèmes Courants

1. **Erreur d'authentification 401**:
   - Vérifier les credentials dans le secret
   - Redémarrer Traefik: `kubectl rollout restart deployment/traefik -n kube-system`

2. **Certificat SSL invalide**:
   - Vérifier cert-manager: `kubectl get certificates -n monitoring`
   - Forcer renouvellement: `kubectl delete secret prometheus-tls grafana-tls -n monitoring`

3. **Service inaccessible**:
   - Vérifier DNS: `nslookup prometheus.gotravelyzer.com`
   - Vérifier ingress: `kubectl describe ingress -n monitoring`

### Tests de Connectivité

```bash
# Test authentification Prometheus
curl -u backlight:QR4xQ7QL5ppPhp https://prometheus.gotravelyzer.com

# Test SSL
curl -I https://grafana.gotravelyzer.com
```

## Maintenance

### Renouvellement de Certificats
- **Automatique**: cert-manager gère le renouvellement
- **Vérification**: `kubectl get certificates -n monitoring`

### Sauvegarde des Configurations
- Tous les fichiers YAML sont versionnés dans Git
- Secrets récupérables via kubectl

### Mise à Jour des Credentials
1. Modifier le fichier `prometheus-auth-secret.yaml`
2. Appliquer: `kubectl apply -f monitoring/`
3. Redémarrer Traefik pour rechargement
4. Commiter les changements dans Git

## Sécurité

### Bonnes Pratiques
- ✅ SSL/TLS activé avec Let's Encrypt
- ✅ Authentification Basic Auth pour Prometheus
- ✅ Certificates automatiquement renouvelés
- ✅ Credentials stockés dans Kubernetes Secrets
- ✅ Accès restreint par middleware Traefik

### Recommandations
- Changer les credentials régulièrement
- Surveiller les logs d'accès
- Utiliser des mots de passe forts
- Restreindre l'accès par IP si nécessaire