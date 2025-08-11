#!/bin/bash

# Script pour forcer le redéploiement quand latest est mis à jour
echo "Forçage du redéploiement des services..."

kubectl rollout restart deployment/api-gateway -n app
kubectl rollout restart deployment/api-enrichment -n app  
kubectl rollout restart deployment/api-generation -n app

echo "Redéploiements lancés ✅"