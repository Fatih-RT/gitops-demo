#!/usr/bin/env bash
# TP1 - Etapes 1 a 16 : cluster Minikube (driver=none) avec cri-dockerd sur Ubuntu 25.04.
# A lancer sur la VM Ubuntu, avec un utilisateur normal membre du groupe sudo.
# Usage : ./scripts/01-install-minikube.sh
set -euo pipefail

CRICTL_VERSION="v1.29.0"
CNI_VERSION="v1.1.1"
K8S_VERSION="v1.29.0"

echo "==> 1. Mise a jour systeme"
sudo apt update && sudo apt upgrade -y

echo "==> 2. Dependances"
sudo apt install -y curl wget apt-transport-https conntrack socat gpg lsb-release \
  open-vm-tools open-vm-tools-desktop

echo "==> 3. Desactivation du swap (kubelet refuse de demarrer sinon)"
sudo swapoff -a
sudo sed -i '/ swap /s/^/#/' /etc/fstab

echo "==> 4. Docker"
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
docker --version
echo "    (se deconnecter/reconnecter pour que l'appartenance au groupe docker prenne effet)"

echo "==> 5. Minikube"
wget -q https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb
rm -f minikube_latest_amd64.deb

echo "==> 6. cri-dockerd (interface CRI pour Docker)"
sudo apt install -y golang-go git
if [ ! -d "$HOME/cri-dockerd" ]; then
  git clone https://github.com/Mirantis/cri-dockerd.git "$HOME/cri-dockerd"
fi
pushd "$HOME/cri-dockerd" >/dev/null
mkdir -p bin
go build -o bin/cri-dockerd          # environ 2 minutes
sudo mkdir -p /usr/local/bin
sudo install bin/cri-dockerd /usr/local/bin/
sudo cp -a packaging/systemd/* /etc/systemd/system
sudo sed -i 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
sudo systemctl daemon-reload
sudo systemctl enable --now cri-docker.service cri-docker.socket
popd >/dev/null
sudo systemctl --no-pager status cri-docker.service | head -5

echo "==> 7. crictl ${CRICTL_VERSION}"
wget -q "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
sudo tar zxf "crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" -C /usr/local/bin
sudo chmod +x /usr/local/bin/crictl
rm -f "crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
crictl --version

echo "==> 8. Module kernel br_netfilter et parametres sysctl"
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
cat <<'SYSCTL' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
SYSCTL
sudo sysctl --system >/dev/null

echo "==> 9. Plugins CNI ${CNI_VERSION}"
wget -q "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar -xzf "cni-plugins-linux-amd64-${CNI_VERSION}.tgz" -C /opt/cni/bin
rm -f "cni-plugins-linux-amd64-${CNI_VERSION}.tgz"

echo "==> 10. fs.protected_regular=0 (evite les erreurs de permission du driver none)"
sudo sysctl fs.protected_regular=0
grep -q '^fs.protected_regular' /etc/sysctl.conf || echo "fs.protected_regular=0" | sudo tee -a /etc/sysctl.conf

echo "==> 11. CHANGE_MINIKUBE_NONE_USER"
export CHANGE_MINIKUBE_NONE_USER=true
grep -q CHANGE_MINIKUBE_NONE_USER "$HOME/.bashrc" || echo 'export CHANGE_MINIKUBE_NONE_USER=true' >> "$HOME/.bashrc"

echo "==> 12. Demarrage de Minikube"
sudo minikube delete --all --force || true
sudo minikube start --driver=none --container-runtime=docker \
  --cri-socket=/var/run/cri-dockerd.sock --kubernetes-version="${K8S_VERSION}"

echo "==> 13/14. Recuperation de la kubeconfig pour l'utilisateur courant"
sudo cp -r /root/.kube "$HOME/"
sudo cp -r /root/.minikube "$HOME/"
sudo chown -R "$(id -u):$(id -g)" "$HOME/.kube" "$HOME/.minikube"
sed -i "s|/root/.minikube|$HOME/.minikube|g" "$HOME/.kube/config"

echo "==> 15. kubectl"
command -v kubectl >/dev/null || sudo snap install kubectl --classic

echo "==> 16. Verification"
kubectl get nodes
kubectl get pods -A
