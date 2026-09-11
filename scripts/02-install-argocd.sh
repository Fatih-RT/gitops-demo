#!/usr/bin/env bash
# TP1 - Etapes 17 a 18 : installation d'ArgoCD et de la CLI argocd.
# Usage : ./scripts/02-install-argocd.sh
set -euo pipefail

echo "==> Namespace argocd"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installation d'ArgoCD"
# --server-side est obligatoire ici : la definition de ressource
# applicationsets.argoproj.io depasse la limite de 262144 octets imposee a
# l'annotation last-applied-configuration qu'ecrit un apply classique.
# Sans cette option, l'installation echoue sur cette seule ressource.
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> Attente du demarrage des pods (jusqu'a 5 minutes)"
kubectl wait --for=condition=available --timeout=300s deployment --all -n argocd
kubectl get pods -n argocd

echo "==> Installation de la CLI argocd"
if ! command -v argocd >/dev/null; then
  sudo snap install argocd --classic
fi
argocd version --client --short || true

echo
echo "Mot de passe admin initial :"
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
echo
echo "Etape suivante : ./scripts/03-argocd-access.sh"
