#!/usr/bin/env bash
# TP1 (guestbook) + TP2 (nginx-demo) : creation des applications ArgoCD.
# Prerequis : port-forward actif (./scripts/03-argocd-access.sh) dans un autre terminal.
# Usage : ./scripts/04-deploy-apps.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Namespaces cibles"
for ns in guestbook-gui guestbook-cli nginx-demo; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

echo "==> Applications ArgoCD (mode declaratif : les Application sont elles-memes du code)"
kubectl apply -n argocd -f argocd/

echo "==> Synchronisation via la CLI"
ARGOCD_PASSWORD="$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
argocd login localhost:8888 --username admin --password "${ARGOCD_PASSWORD}" --insecure

for app in guestbook-gui guestbook-cli nginx-demo; do
  argocd app sync "$app"
  argocd app wait "$app" --health --timeout 180
done

echo "==> Etat final"
argocd app list
kubectl get pods,svc -n nginx-demo

MINIKUBE_IP="$(minikube ip 2>/dev/null || sudo minikube ip)"
echo
echo "Application NGINX : http://${MINIKUBE_IP}:30080"
echo "Guestbook GUI     : kubectl port-forward svc/guestbook-ui 8081:80 -n guestbook-gui"
echo "Guestbook CLI     : kubectl port-forward svc/guestbook-ui 8082:80 -n guestbook-cli"
