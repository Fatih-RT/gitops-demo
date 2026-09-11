# Déploiement du TP sur Proxmox

Automatisation Ansible qui crée la VM du TP sur un nœud Proxmox, puis y installe les trois TP :
cluster Minikube, ArgoCD avec ses applications, et les scans Trivy.

Une seule commande à la fin :

```bash
ansible-playbook site.yml
```

## 1. Préparer le poste qui lance Ansible

```bash
ansible-galaxy collection install -r requirements.yml
pip install -r requirements.txt
```

Les modules Proxmox ne font plus partie de `community.general`. Ils vivent dans la collection
`community.proxmox`, et s'appuient sur la bibliothèque Python `proxmoxer`.

## 2. Créer le template cloud-init sur le nœud Proxmox

Copier le script sur le nœud, puis l'exécuter en root :

```bash
scp scripts/create-cloudinit-template.sh root@pve:/tmp/
ssh root@pve "VMID=9000 STORAGE=local-lvm BRIDGE=vmbr0 bash /tmp/create-cloudinit-template.sh"
```

Le script télécharge l'image cloud officielle d'Ubuntu, crée la VM, y attache le disque cloud-init
puis la convertit en template. Il refuse de s'exécuter si l'identifiant de VM est déjà pris.

## 3. Créer un jeton d'API

Dans l'interface Proxmox, **Datacenter > Permissions > API Tokens > Add**.

- Utilisateur dédié plutôt que `root@pam`, par exemple `ansible@pve`.
- Décocher **Privilege Separation**, ou attribuer explicitement les droits au jeton.
- Droits nécessaires sur `/` : rôle `PVEVMAdmin`, plus `Datastore.AllocateSpace` et
  `Datastore.Audit` sur le stockage cible.

Proxmox n'affiche la valeur du secret qu'une seule fois. La coller directement dans le shell, et
nulle part ailleurs :

```bash
export PROXMOX_HOST=192.168.1.10
export PROXMOX_USER=ansible@pve
export PROXMOX_TOKEN_ID=ansible
read -rs PROXMOX_TOKEN_SECRET && export PROXMOX_TOKEN_SECRET
```

`read -rs` évite que le secret apparaisse à l'écran et dans l'historique du shell. Aucun de ces
identifiants n'est écrit dans le dépôt : les variables sont lues dans l'environnement.

## 4. Adapter les variables

Tout se règle dans [`group_vars/all.yml`](group_vars/all.yml) :

| Variable | Rôle |
| --- | --- |
| `proxmox_node` | nom du nœud Proxmox |
| `vm_template` | nom du template créé à l'étape 2 |
| `vm_storage` | stockage des disques |
| `vm_ip`, `vm_gateway` | adressage de la VM |
| `vm_cores`, `vm_memory`, `vm_disk_size` | gabarit |
| `vm_user`, `ssh_public_key_file` | compte créé par cloud-init |

L'adresse fixe est conseillée : l'application du TP2 est exposée en NodePort sur cette adresse.
En DHCP, mettre `vm_ip: dhcp`, relever l'adresse dans Proxmox, puis relancer avec
`-e vm_address=<adresse>`.

## 5. Lancer

```bash
ansible-playbook site.yml
```

Le playbook enchaîne :

1. clonage du template, redimensionnement du disque, configuration cloud-init, démarrage ;
2. attente du port SSH, puis clonage du dépôt des TP dans la VM ;
3. exécution du script d'installation de Minikube, puis celui d'ArgoCD ;
4. création des applications ArgoCD en mode déclaratif, sans CLI ni port-forward ;
5. installation de Trivy, scan des deux images, rapports rapatriés dans `rapports/`.

Compter entre vingt et trente minutes, l'essentiel étant la compilation de cri-dockerd et le
démarrage du cluster. Les playbooks sont rejouables : les étapes déjà faites sont ignorées.

## Après l'exécution

| Accès | Commande ou adresse |
| --- | --- |
| Application NGINX du TP2 | `http://<adresse_vm>:30080` |
| Interface ArgoCD | `ssh -L 8888:localhost:8888 <user>@<adresse_vm>` puis un port-forward dans la VM |
| Rapports Trivy | dossier `rapports/` sur le poste local |

Le mot de passe admin d'ArgoCD est affiché à la fin du playbook. Le changer, puis supprimer le
secret `argocd-initial-admin-secret`.

## État de validation

Ces playbooks n'ont jamais été exécutés contre un vrai Proxmox : je n'ai pas accès au tien. La
syntaxe Ansible est vérifiée et les modules employés existent bien dans la version installée de la
collection. Le comportement réel reste à confirmer au premier passage.

Deux points à surveiller au premier essai :

- le nom du stockage et celui du pont réseau diffèrent souvent d'une installation à l'autre ;
- les droits du jeton d'API sont la cause la plus fréquente d'échec au clonage.
