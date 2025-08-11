#!/bin/bash

echo "🔍 Vérification des nouvelles images disponibles..."

# Fonction pour mettre à jour un déploiement si nécessaire
update_deployment() {
    local service=$1
    local namespace="app"
    
    # Récupérer l'image actuelle du deployment
    current_image=$(kubectl get deployment $service -n $namespace -o jsonpath='{.spec.template.spec.containers[0].image}')
    
    # Récupérer la dernière image de l'ImagePolicy
    latest_image=$(kubectl get imagepolicy $service -n flux-system -o jsonpath='{.status.latestImage}')
    
    if [ "$current_image" != "$latest_image" ] && [ -n "$latest_image" ]; then
        echo "🚀 Mise à jour de $service:"
        echo "   Actuelle: $current_image"
        echo "   Nouvelle: $latest_image"
        
        kubectl patch deployment $service -n $namespace -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"app\",\"image\":\"$latest_image\"}]}}}}"
        echo "✅ $service mis à jour avec succès!"
    else
        echo "✓ $service déjà à jour"
    fi
}

# Mettre à jour tous les services
update_deployment "api-gateway"
update_deployment "api-enrichment" 
update_deployment "api-generation"

echo "🎉 Vérification terminée!"