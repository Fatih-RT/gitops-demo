#!/usr/bin/env bash
# Nettoyage des ressources creees par les TP1 et TP2.
# Le cluster Minikube lui-meme n'est supprime que si on passe --all.
set -euo pipefail

for app in guestbook-gui guestbook-cli nginx-demo; do
  kubectl delete application "$app" -n argocd --ignore-not-found
done

for ns in guestbook-gui guestbook-cli nginx-demo; do
  kubectl delete namespace "$ns" --ignore-not-found
done

if [ "${1:-}" = "--all" ]; then
  kubectl delete namespace argocd --ignore-not-found
  sudo minikube delete --all --force
fi
