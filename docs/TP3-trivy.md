# TP3 — Détection et correction de vulnérabilités Docker avec Trivy

**Objectif** : scanner une image Docker obsolète, relever les vulnérabilités critiques, reconstruire
une image à jour et vérifier la disparition de ces vulnérabilités.

## Workflow

1. build d'une image volontairement vulnérable ;
2. scan Trivy, lecture des CVE ;
3. correction du Dockerfile ;
4. build de l'image corrigée ;
5. second scan et comparaison.

## Prérequis

```bash
docker --version
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh
sudo chmod +x /usr/local/bin/trivy
trivy --version        # version 0.65.0 utilisée pour le TP
```

Trivy est lancé avec `sudo` pour accéder au socket Docker sans ajuster les droits du groupe.

## Étape 1 — Image vulnérable

[`trivy/Dockerfile.vulnerable`](../trivy/Dockerfile.vulnerable) :

```dockerfile
FROM node:12-alpine
```

Node 12 est en fin de vie depuis avril 2022 : la branche ne reçoit plus de correctifs, et l'image
Alpine associée embarque des versions figées d'OpenSSL, de busybox et des bibliothèques système.

```bash
docker build -t node-vulnerable -f Dockerfile.vulnerable .
sudo trivy image node-vulnerable
```

Une vingtaine de vulnérabilités remontent, dont plusieurs `CRITICAL`.

## Étape 2 — Image corrigée

[`trivy/Dockerfile.fixed`](../trivy/Dockerfile.fixed) :

```dockerfile
FROM node:20-alpine
RUN apk upgrade --no-cache
```

Deux corrections combinées : une base encore maintenue, et la mise à jour des paquets Alpine au
moment du build, qui rattrape les correctifs publiés depuis la construction de l'image officielle.

```bash
docker build -t node-fixed -f Dockerfile.fixed .
sudo trivy image node-fixed
```

Le résultat attendu est zéro vulnérabilité critique, ou un nombre très réduit.

### Résultat observé dans la CI de ce dépôt

Le scan lancé par GitHub Actions le 11 septembre 2026 sur `node-fixed` donne deux constats opposés :

| Périmètre | CRITICAL | HIGH |
| --- | --- | --- |
| Paquets système (Alpine 3.23.4) | 0 | 0 |
| Dépendances npm embarquées dans l'image | 1 | 19 |

La couche système est propre : la mise à jour de la base a fait son travail. En revanche, le npm
livré dans l'image officielle embarque des bibliothèques JavaScript vulnérables, dont `tar` en
CVE-2026-59873 (déni de service par archive gzip piégée, sévérité CRITICAL), ainsi que `minimatch`,
`brace-expansion`, `glob`, `cross-spawn` et `sigstore`.

Enseignement principal du TP : **changer d'image de base corrige le système, pas les dépendances
applicatives**. Il faut les deux, analyse d'image et analyse de composants (SCA), sur des
périmètres distincts. C'est pourquoi le workflow sépare les deux scans, bloquant sur le système,
informatif sur les bibliothèques, le temps de traiter ces dépendances à la source.

## Étape 3 — Comparaison

Le script [`trivy/scan.sh`](../trivy/scan.sh) enchaîne les deux builds, les deux scans, écrit les
rapports texte et JSON dans `trivy/rapports/`, et affiche le décompte par sévérité.

```bash
./trivy/scan.sh
```

Les résultats relevés sur la VM sont consignés dans [`trivy/RESULTATS.md`](../trivy/RESULTATS.md).

## Lire un rapport Trivy

| Colonne | Signification |
| --- | --- |
| Severity | LOW, MEDIUM, HIGH, CRITICAL |
| Library | paquet ou composant affecté |
| Vulnerability | identifiant CVE, avec lien vers la base |
| Installed Version | version vulnérable présente dans l'image |
| Fixed Version | version corrigée, si elle existe |

Trois cas concrets rencontrés dans ce type d'image :

- `coreutils` / CVE-2016-2781 : faille ancienne, jamais corrigée en amont ;
- `curl` / CVE-2025-0725 : faille récente et critique, corrigée par une mise à jour de paquet ;
- statut `will_not_fix` : l'éditeur ne prévoit aucun correctif, il faut alors changer de base,
  supprimer le paquet, ou accepter le risque et le documenter.

## Bonnes pratiques retenues

- partir d'une image de base récente et encore supportée ;
- figer le tag, jamais `latest`, pour que l'image scannée soit celle qui tourne ;
- mettre à jour les paquets au build (`apk upgrade --no-cache` sur Alpine) ;
- scanner systématiquement avant déploiement, et bloquer la chaîne en cas de CRITICAL ;
- reconstruire sans cache en cas de doute : `docker build --no-cache ...`.

## Intégration CI — le scan comme garde-fou

Le workflow [`.github/workflows/trivy-scan.yml`](../.github/workflows/trivy-scan.yml) rejoue ce TP à
chaque push : il construit les deux images, scanne l'image corrigée et fait échouer le job si un
paquet système `CRITICAL` ou `HIGH` disposant d'un correctif est détecté. Les vulnérabilités des
bibliothèques embarquées sont affichées sans bloquer, et les manifests Kubernetes du dossier `app/`
sont analysés pour les erreurs de configuration. Un scan hebdomadaire est également planifié, car de
nouvelles CVE apparaissent sur une image qui n'a pourtant pas changé.

C'est la traduction concrète du *shift left* : la vulnérabilité est détectée au commit, pas en
production.

## Conclusion

Même les images officielles contiennent des vulnérabilités connues. Le scan n'est utile que s'il est
automatisé et bloquant. Une image « propre » aujourd'hui ne le reste pas : de nouvelles CVE sont
publiées en permanence sur des images inchangées, d'où l'intérêt d'un scan périodique en plus du
scan au build.
