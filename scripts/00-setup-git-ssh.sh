#!/usr/bin/env bash
# TP2 - Etape 0 : cle SSH de la VM ArgoCD vers GitHub + identite Git.
# A lancer avec l'utilisateur normal de la VM, jamais en root.
# Usage : ./scripts/00-setup-git-ssh.sh "prenom.nom@example.com" "Prenom Nom"
set -euo pipefail

EMAIL="${1:?Usage: $0 <email-github> <nom complet>}"
NAME="${2:?Usage: $0 <email-github> <nom complet>}"
KEY="$HOME/.ssh/id_ed25519"

if [ ! -f "$KEY" ]; then
  # -N "" : pas de passphrase, pour que ArgoCD et git push n'en demandent pas.
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY" -N ""
fi

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"
git config --global init.defaultBranch main

echo
echo "Cle publique a coller dans GitHub > Settings > SSH and GPG keys > New SSH key :"
echo
cat "${KEY}.pub"
echo
echo "Ensuite, tester : ssh -T git@github.com"
echo "La cle PRIVEE (${KEY}) ne doit jamais etre commitee. Elle sert uniquement a"
echo "declarer le depot dans ArgoCD > Settings > Repositories > Connect Repo using SSH."
