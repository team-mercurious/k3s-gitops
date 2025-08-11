#!/bin/bash

echo "🔐 Accès aux interfaces de monitoring sécurisées"
echo "================================================"

# Vérifier que les services sont running
echo "📊 Vérification des services..."
GRAFANA_STATUS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers | awk '{print $3}')
PROMETHEUS_STATUS=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers | awk '{print $3}')

if [ "$GRAFANA_STATUS" = "Running" ] && [ "$PROMETHEUS_STATUS" = "Running" ]; then
    echo "✅ Services de monitoring opérationnels"
else
    echo "❌ Services non disponibles"
    echo "Grafana: $GRAFANA_STATUS"
    echo "Prometheus: $PROMETHEUS_STATUS"
    exit 1
fi

echo ""
echo "🔑 Identifiants Grafana:"
echo "Username: admin"
echo "Password: admin123"
echo ""

echo "🌐 Choisissez l'interface à ouvrir:"
echo "1) Grafana (Interface principale - recommandé)"
echo "2) Prometheus (Métriques et queries)"  
echo "3) AlertManager (Gestion des alertes)"
echo "4) Tous les services"
echo ""
read -p "Votre choix (1-4): " choice

case $choice in
    1)
        echo "🎯 Ouverture de Grafana..."
        echo "URL: http://localhost:3000"
        echo "Login: admin / admin123"
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
        ;;
    2)
        echo "📈 Ouverture de Prometheus..."
        echo "URL: http://localhost:9090"
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
        ;;
    3)
        echo "🚨 Ouverture d'AlertManager..."
        echo "URL: http://localhost:9093"
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
        ;;
    4)
        echo "🌐 Ouverture de tous les services..."
        echo "Grafana: http://localhost:3000 (admin/admin123)"
        echo "Prometheus: http://localhost:9090"
        echo "AlertManager: http://localhost:9093"
        echo ""
        echo "🔄 Démarrage des port-forwards en parallèle..."
        
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
        GRAFANA_PID=$!
        
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
        PROMETHEUS_PID=$!
        
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &
        ALERTMANAGER_PID=$!
        
        echo "✅ Services disponibles:"
        echo "- Grafana: http://localhost:3000"
        echo "- Prometheus: http://localhost:9090" 
        echo "- AlertManager: http://localhost:9093"
        echo ""
        echo "Appuyez sur Ctrl+C pour arrêter tous les port-forwards"
        
        trap 'kill $GRAFANA_PID $PROMETHEUS_PID $ALERTMANAGER_PID 2>/dev/null; exit' INT
        wait
        ;;
    *)
        echo "❌ Choix invalide"
        exit 1
        ;;
esac