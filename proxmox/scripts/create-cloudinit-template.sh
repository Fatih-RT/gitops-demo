#!/usr/bin/env bash
# Crée le template cloud-init Ubuntu utilisé par le playbook.
# À exécuter SUR LE NŒUD PROXMOX, en root. Nécessite Proxmox VE 8 ou plus récent
# pour l'option import-from.
#
#   VMID=9000 STORAGE=local-lvm BRIDGE=vmbr0 ./create-cloudinit-template.sh
set -euo pipefail

VMID="${VMID:-9000}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
RELEASE="${RELEASE:-25.04}"
NAME="${NAME:-ubuntu-$(echo "$RELEASE" | tr -d '.')-cloudinit}"

IMG_URL="https://cloud-images.ubuntu.com/releases/${RELEASE}/release/ubuntu-${RELEASE}-server-cloudimg-amd64.img"
IMG="/var/lib/vz/template/iso/$(basename "$IMG_URL")"

if qm status "$VMID" >/dev/null 2>&1; then
  echo "La VM ${VMID} existe déjà. Choisir un autre VMID ou la supprimer."
  exit 1
fi

echo "==> Téléchargement de l'image cloud Ubuntu ${RELEASE}"
mkdir -p "$(dirname "$IMG")"
[ -f "$IMG" ] || wget -q --show-progress -O "$IMG" "$IMG_URL"

echo "==> Création de la VM ${VMID}"
qm create "$VMID" \
  --name "$NAME" \
  --machine q35 \
  --cpu host \
  --cores 2 \
  --memory 4096 \
  --net0 "virtio,bridge=${BRIDGE}" \
  --scsihw virtio-scsi-single \
  --ostype l26 \
  --agent enabled=1

echo "==> Import du disque et configuration cloud-init"
qm set "$VMID" --scsi0 "${STORAGE}:0,import-from=${IMG}"
qm set "$VMID" --ide2 "${STORAGE}:cloudinit"
qm set "$VMID" --boot order=scsi0
# Console série : indispensable pour lire les logs cloud-init depuis l'interface.
qm set "$VMID" --serial0 socket --vga serial0

echo "==> Conversion en template"
qm template "$VMID"

echo
echo "Template ${NAME} (id ${VMID}) prêt."
echo "Reporter ce nom dans proxmox/group_vars/all.yml, variable vm_template."
