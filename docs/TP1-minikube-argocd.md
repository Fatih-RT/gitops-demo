# TP1 — Minikube (driver=none) + ArgoCD

**Objectif** : installer un cluster Kubernetes local avec Minikube en `--driver=none` sur Ubuntu 25.04,
puis y déployer ArgoCD et deux applications Guestbook, une via l'interface graphique, une via la CLI.

Script correspondant : [`scripts/01-install-minikube.sh`](../scripts/01-install-minikube.sh) et
[`scripts/02-install-argocd.sh`](../scripts/02-install-argocd.sh).

## Prérequis

- VM Ubuntu 25.04 avec la virtualisation imbriquée activée dans VMware.
- VMware Tools installés : `sudo apt-get install open-vm-tools open-vm-tools-desktop`.
- Un utilisateur normal membre du groupe `sudo`.

## 1. Préparation du système

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget apt-transport-https conntrack socat gpg lsb-release
sudo swapoff -a
sudo sed -i '/ swap /s/^/#/' /etc/fstab
```

Le swap doit être désactivé, sinon `kubelet` refuse de démarrer. La ligne commentée dans `/etc/fstab`
rend la désactivation permanente après redémarrage.

## 2. Docker et cri-dockerd

Depuis Kubernetes 1.24, le dockershim a été retiré du kubelet. Avec `--driver=none` et Docker comme
runtime, il faut donc l'adaptateur `cri-dockerd` de Mirantis.

```bash
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER      # nécessite une reconnexion
docker run hello-world
```

Compilation et installation de `cri-dockerd` :

```bash
sudo apt install -y golang-go git
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd && mkdir bin && go build -o bin/cri-dockerd   # environ 2 min
sudo install bin/cri-dockerd /usr/local/bin/
sudo cp -a packaging/systemd/* /etc/systemd/system
sudo sed -i 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
sudo systemctl daemon-reload
sudo systemctl enable --now cri-docker.service cri-docker.socket
```

Vérification : `sudo systemctl status cri-docker.service` et `cri-docker.socket` doivent être `active`.

## 3. Outils et paramètres kernel

| Élément | Version | Rôle |
| --- | --- | --- |
| crictl | v1.29.0 | client CRI attendu par Kubernetes 1.29+ |
| plugins CNI | v1.1.1 | réseau des pods, obligatoire avec le driver `none` |
| Kubernetes | v1.29.0 | version du cluster Minikube |

```bash
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
sudo sysctl fs.protected_regular=0
export CHANGE_MINIKUBE_NONE_USER=true
```

`br_netfilter` permet à iptables de voir le trafic des bridges, indispensable pour les règles de
service Kubernetes. `fs.protected_regular=0` évite les erreurs de permission propres au driver `none`.

## 4. Démarrage du cluster

```bash
sudo minikube delete --all --force
sudo minikube start --driver=none --container-runtime=docker \
  --cri-socket=/var/run/cri-dockerd.sock --kubernetes-version=v1.29.0
```

Le driver `none` fait tourner Kubernetes directement sur l'hôte, en root. Il faut donc récupérer la
kubeconfig pour l'utilisateur courant :

```bash
sudo cp -r /root/.kube ~/ && sudo cp -r /root/.minikube ~/
sudo chown -R $(id -u):$(id -g) ~/.kube ~/.minikube
sed -i "s|/root/.minikube|$HOME/.minikube|g" ~/.kube/config
sudo snap install kubectl --classic
kubectl get nodes
kubectl get pods -A
```

Le nœud doit apparaître en `Ready` et tous les pods de `kube-system` en `Running`.

## 5. Installation d'ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd
```

Accès à l'interface, en port-forward local uniquement :

```bash
kubectl port-forward svc/argocd-server -n argocd 8888:80
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo
```

Connexion sur `http://localhost:8888` avec `admin` et le mot de passe affiché.

> Point de sécurité : le mot de passe initial est stocké en clair dans le secret
> `argocd-initial-admin-secret`. Il faut le changer puis supprimer le secret
> (`argocd account update-password`, puis `kubectl delete secret argocd-initial-admin-secret -n argocd`).
> Le port-forward n'écoute que sur la boucle locale, l'interface n'est donc jamais exposée au réseau.

## 6. Déploiement des deux applications Guestbook

### Méthode 1 — interface graphique

```bash
kubectl create namespace guestbook-gui
```

Dans l'interface, **NEW APP** puis :

| Champ | Valeur |
| --- | --- |
| Application Name | guestbook-gui |
| Project | default |
| Sync Policy | Manual |
| Repository URL | https://github.com/argoproj/argocd-example-apps.git |
| Revision | HEAD |
| Path | guestbook |
| Cluster URL | https://kubernetes.default.svc |
| Namespace | guestbook-gui |

Puis **CREATE** et **SYNC**. Vérification :

```bash
kubectl port-forward svc/guestbook-ui 8081:80 -n guestbook-gui
```

### Méthode 2 — ligne de commande

```bash
sudo snap install argocd --classic
kubectl create namespace guestbook-cli
argocd login localhost:8888 --username admin --password <MOT_DE_PASSE> --insecure

argocd app create guestbook-cli \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace guestbook-cli

argocd app sync guestbook-cli
argocd app get guestbook-cli
kubectl port-forward svc/guestbook-ui 8082:80 -n guestbook-cli
```

Les équivalents déclaratifs de ces deux applications sont versionnés dans
[`argocd/guestbook-gui.yaml`](../argocd/guestbook-gui.yaml) et
[`argocd/guestbook-cli.yaml`](../argocd/guestbook-cli.yaml). C'est la forme à privilégier :
l'application elle-même devient du code revu et tracé, au lieu d'un clic dans une interface.

## Résultat attendu

Deux applications `Synced` / `Healthy` dans ArgoCD, et deux Guestbook accessibles sur les ports
8081 et 8082 en local.

## Problèmes rencontrés et solutions

| Symptôme | Cause | Correction |
| --- | --- | --- |
| `kubelet` ne démarre pas | swap encore actif | `sudo swapoff -a` puis commenter la ligne dans `/etc/fstab` |
| `permission denied` sur `~/.kube/config` | fichiers créés par root avec le driver `none` | `chown` puis `sed` du chemin `/root/.minikube` |
| `docker: permission denied` | groupe `docker` pas encore appliqué | se déconnecter / reconnecter |
| Pods `ContainerCreating` sans fin | plugins CNI absents | installer les plugins CNI dans `/opt/cni/bin` |
