# TP2 — GitOps complet : GitHub → ArgoCD → Kubernetes

**Objectif** : relier ce dépôt Git à ArgoCD, déployer NGINX à partir des manifests versionnés, puis
modifier la page d'accueil par un ConfigMap et observer la propagation automatique.

## Flux GitOps

```
git push ──► GitHub (source de vérité)
                │  polling toutes les 3 min, ou webhook
                ▼
            ArgoCD ──► compare l'état désiré (Git) et l'état réel (cluster)
                │
                ▼
        Kubernetes (namespace nginx-demo) ──► Service NodePort 30080 ──► navigateur
```

Le principe : personne ne modifie le cluster à la main. Toute modification passe par un commit, ce
qui donne l'audit, la revue et le retour arrière gratuitement. C'est ce qui rend GitOps intéressant
du point de vue sécurité.

## Étape 0 — SSH de la VM vers GitHub

```bash
ssh-keygen -t ed25519 -C "ton_email_github"      # passphrase vide
cat ~/.ssh/id_ed25519.pub                        # à coller dans GitHub > Settings > SSH and GPG keys
ssh -T git@github.com                            # doit répondre : Hi Fatih-RT! You've successfully authenticated...
git config --global user.name  "Ton Nom"
git config --global user.email "ton_email_github"
```

Automatisé par [`scripts/00-setup-git-ssh.sh`](../scripts/00-setup-git-ssh.sh).

## Étape 1 — Dépôt Git

Dépôt utilisé : **https://github.com/Fatih-RT/gitops-demo**, branche `main`.

```bash
mkdir ~/gitops-demo && cd ~/gitops-demo
git init
git remote add origin git@github.com:Fatih-RT/gitops-demo.git
echo "# Démo GitOps avec ArgoCD" > README.md
git add . && git commit -m "Premier commit - Initialisation"
git branch -m master main     # si la branche locale s'appelle encore master
git push -u origin main
```

L'erreur « le spécificateur de référence source main ne correspond à aucune référence » signifie
simplement que la branche `main` n'existe pas encore localement. `git branch` affiche la branche
active, `git branch -m master main` la renomme. `main` est la convention GitHub actuelle.

Organisation retenue :

```
gitops-demo/
├── app/        # manifests Kubernetes synchronisés par ArgoCD
├── argocd/     # définitions des Application ArgoCD (GitOps appliqué à ArgoCD lui-même)
├── trivy/      # TP3
├── scripts/    # installation et déploiement automatisés
└── docs/       # comptes rendus
```

## Étape 2 — Manifests NGINX

[`app/deployment.yaml`](../app/deployment.yaml) : 2 réplicas, image `nginx:1.25.1`.
[`app/service.yaml`](../app/service.yaml) : Service `NodePort` sur le port 30080.

Le tag de l'image est figé. Utiliser `nginx:latest` empêcherait de savoir quelle version tourne
réellement, et rendrait tout scan de vulnérabilités non reproductible.

```bash
git add app/deployment.yaml app/service.yaml
git commit -m "Ajout manifests NGINX"
git push origin main
```

## Étape 3 — Déploiement via ArgoCD

```bash
kubectl create namespace nginx-demo
```

Le dépôt du TP était privé. Deux solutions étaient possibles :

1. rendre le dépôt public, ArgoCD y accède sans authentification ;
2. déclarer une clé SSH de déploiement dans ArgoCD.

Ce dépôt est **public**, donc ArgoCD le clone en HTTPS sans identifiants. Pour un dépôt privé, la
procédure est la suivante :

- **Settings > Repositories > Connect Repo using SSH** dans l'interface ArgoCD ;
- URL : `git@github.com:Fatih-RT/gitops-demo.git` ;
- coller la clé **privée** (`cat ~/.ssh/id_ed25519`) dans le champ dédié ;
- valider, ArgoCD teste la connexion.

> La clé privée ne doit jamais être commitée. Dans un contexte réel on utilise une *deploy key*
> dédiée en lecture seule, et non la clé personnelle du développeur, pour que la révocation soit
> possible sans casser les accès de la personne.

Création de l'application :

```bash
argocd app create nginx-demo \
  --repo https://github.com/Fatih-RT/gitops-demo.git \
  --path app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace nginx-demo

argocd app sync nginx-demo
```

Équivalent déclaratif, versionné dans [`argocd/nginx-demo.yaml`](../argocd/nginx-demo.yaml) :

```bash
kubectl apply -n argocd -f argocd/nginx-demo.yaml
```

Cette version active en plus `automated.prune` et `automated.selfHeal` : ArgoCD supprime du cluster
ce qui disparaît de Git, et annule toute modification faite directement sur le cluster. Une
modification manuelle non tracée est donc automatiquement corrigée.

### Vérifications

```bash
kubectl get pods -n nginx-demo     # 2 pods Running
kubectl get svc  -n nginx-demo     # nginx-service NodePort 80:30080/TCP
minikube ip
```

Accès navigateur : `http://<minikube_ip>:30080`.

## Étape 4 — ConfigMap et mise à jour automatique

L'image NGINX embarque sa propre page d'accueil. Pour la remplacer sans reconstruire d'image, on
monte un ConfigMap sur `/usr/share/nginx/html/index.html`.

[`app/configmap.yaml`](../app/configmap.yaml) contient le HTML, et le Deployment le monte via
`volumeMounts` + `subPath` :

```yaml
volumeMounts:
  - name: nginx-index-volume
    mountPath: /usr/share/nginx/html/index.html
    subPath: index.html
volumes:
  - name: nginx-index-volume
    configMap:
      name: nginx-index
```

```bash
git add app/configmap.yaml app/deployment.yaml
git commit -m "Ajout ConfigMap pour page HTML personnalisée"
git push
argocd app sync nginx-demo        # ou bouton SYNC dans l'interface
```

La page personnalisée apparaît alors sur `http://<minikube_ip>:30080`. Modifier le HTML dans Git et
repousser suffit à mettre à jour l'application : c'est la boucle DevSecOps complète en miniature.

> Détail utile : un ConfigMap monté en `subPath` n'est pas rafraîchi automatiquement dans le
> conteneur. Après modification du HTML seul, il faut `kubectl rollout restart deployment/nginx-deployment -n nginx-demo`,
> ou ajouter une annotation de checksum du ConfigMap dans le template du pod pour forcer un
> redéploiement à chaque changement.

## Conclusion

Le cycle Git → ArgoCD → Kubernetes → navigateur est validé :

1. le dépôt est relié à ArgoCD, en SSH pour un dépôt privé ;
2. ArgoCD déploie depuis le bon chemin (`app/`) et la bonne branche (`main`) ;
3. Kubernetes exécute les pods NGINX ;
4. le Service NodePort expose l'application ;
5. une modification commitée est appliquée automatiquement.
