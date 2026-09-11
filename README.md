# gitops-demo — Module DevSecOps (TP1, TP2, TP3)

[![Scan de sécurité (Trivy)](https://github.com/Fatih-RT/gitops-demo/actions/workflows/trivy-scan.yml/badge.svg)](https://github.com/Fatih-RT/gitops-demo/actions/workflows/trivy-scan.yml)

Dépôt de rendu du module DevSecOps : cluster Kubernetes local, livraison GitOps avec ArgoCD et
analyse de vulnérabilités de conteneurs avec Trivy.

Environnement cible : VM Ubuntu 25.04, Minikube en `--driver=none` avec `cri-dockerd`,
Kubernetes v1.29.0, ArgoCD (manifests `stable`), Trivy 0.65.0.

## Les trois TP

| TP | Sujet | Compte rendu | Livrables |
| --- | --- | --- | --- |
| TP1 | Minikube driver=none + ArgoCD + Guestbook | [docs/TP1-minikube-argocd.md](docs/TP1-minikube-argocd.md) | `scripts/01`, `scripts/02`, `argocd/guestbook-*.yaml` |
| TP2 | GitOps complet GitHub → ArgoCD → Kubernetes | [docs/TP2-gitops-argocd.md](docs/TP2-gitops-argocd.md) | `app/`, `argocd/nginx-demo.yaml` |
| TP3 | Vulnérabilités Docker avec Trivy | [docs/TP3-trivy.md](docs/TP3-trivy.md) | `trivy/`, workflow GitHub Actions |

Repères de cours et panorama d'outils : [docs/outils-devsecops.md](docs/outils-devsecops.md).

## Arborescence

```
.
├── app/                      # manifests Kubernetes synchronisés par ArgoCD (TP2)
│   ├── deployment.yaml       # NGINX 1.25.1, 2 réplicas, ConfigMap monté
│   ├── service.yaml          # NodePort 30080
│   └── configmap.yaml        # page d'accueil personnalisée
├── argocd/                   # Application ArgoCD en mode déclaratif
├── trivy/                    # Dockerfiles vulnérable / corrigé + script de scan
├── scripts/                  # installation et déploiement automatisés
├── docs/                     # comptes rendus des TP
└── .github/workflows/        # porte de sécurité Trivy en CI
```

## Flux GitOps mis en place

```
git push ──► GitHub ──► ArgoCD ──► Kubernetes ──► http://<minikube_ip>:30080
```

ArgoCD compare en continu l'état décrit dans `app/` et l'état réel du cluster. Avec `prune` et
`selfHeal` activés dans [argocd/nginx-demo.yaml](argocd/nginx-demo.yaml), toute dérive est corrigée
automatiquement : le dépôt Git est la seule source de vérité.

## Reproduire le TP sur la VM

```bash
git clone https://github.com/Fatih-RT/gitops-demo.git
cd gitops-demo
chmod +x scripts/*.sh trivy/scan.sh

./scripts/00-setup-git-ssh.sh "email@example.com" "Prenom Nom"   # TP2 étape 0
./scripts/01-install-minikube.sh                                  # TP1, reconnexion requise après
./scripts/02-install-argocd.sh                                    # TP1
./scripts/03-argocd-access.sh                                     # port-forward, à garder ouvert
./scripts/04-deploy-apps.sh                                       # TP1 + TP2, dans un autre terminal
./trivy/scan.sh                                                   # TP3
```

Nettoyage : `./scripts/99-cleanup.sh` (ajouter `--all` pour supprimer aussi ArgoCD et le cluster).

## Accès aux applications

| Application | Accès |
| --- | --- |
| ArgoCD | `http://localhost:8888`, utilisateur `admin` |
| NGINX (TP2) | `http://<minikube_ip>:30080` |
| Guestbook GUI | `kubectl port-forward svc/guestbook-ui 8081:80 -n guestbook-gui` |
| Guestbook CLI | `kubectl port-forward svc/guestbook-ui 8082:80 -n guestbook-cli` |

## Choix de sécurité

- **Tags d'images figés**, jamais `latest` : l'image scannée est bien celle qui s'exécute.
- **Accès ArgoCD par port-forward local** : l'interface n'est pas exposée sur le réseau.
- **Mot de passe admin initial à changer**, puis suppression du secret `argocd-initial-admin-secret`.
- **Aucun secret dans le dépôt** : les clés SSH sont exclues par `.gitignore` et la clé privée n'est
  déclarée que dans ArgoCD.
- **Porte de sécurité en CI** : le workflow Trivy échoue si l'image corrigée contient encore un
  paquet système critique ou élevé disposant d'un correctif. Les vulnérabilités des bibliothèques
  embarquées sont affichées séparément, car elles ne se corrigent pas en changeant d'image de base.
- **Actions GitHub épinglées au commit** et non à un tag : un tag peut être redéplacé vers un autre
  commit, ce qui est un vecteur classique d'attaque sur la chaîne d'approvisionnement.
- **`prune` et `selfHeal`** : aucune modification manuelle du cluster ne survit à la réconciliation.

## Pour aller plus loin

- Remplacer le polling ArgoCD par un webhook GitHub pour une synchronisation immédiate.
- Ajouter une politique d'admission (Kyverno ou OPA Gatekeeper) refusant les images non scannées.
- Durcir les pods : `runAsNonRoot`, `readOnlyRootFilesystem`, suppression des capacités Linux, puis
  rendre bloquant le scan de configuration des manifests.
- Signer les images (Cosign) et vérifier la signature à l'admission.
