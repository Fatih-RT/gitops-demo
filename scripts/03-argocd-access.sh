#!/usr/bin/env bash
# TP1 - Acces a l'interface ArgoCD : port-forward sur localhost uniquement.
# Usage : ./scripts/03-argocd-access.sh   (Ctrl+C pour arreter)
set -euo pipefail

PORT="${1:-8888}"

echo "Mot de passe admin :"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
echo
echo "Interface : http://localhost:${PORT}  (utilisateur : admin)"
echo "Le port-forward n'ecoute que sur localhost : l'interface n'est pas exposee sur le reseau."
kubectl port-forward svc/argocd-server -n argocd "${PORT}:80"
