# TP3 — Relevé des scans Trivy

Mesures faites sur la VM `devsecops-tp` du lab Proxmox, le 11 septembre 2026, avec
`./trivy/scan.sh`. Les rapports complets sont dans `trivy/rapports/` sur la VM, dossier non
versionné.

## Décompte par sévérité

Les deux périmètres sont séparés, car ils ne se corrigent pas de la même façon. Le périmètre
système regroupe les paquets Alpine, le périmètre bibliothèques les dépendances JavaScript
embarquées dans l'image.

| Image | Périmètre | CRITICAL | HIGH | MEDIUM | LOW | Total |
| --- | --- | --- | --- | --- | --- | --- |
| node-vulnerable | système | 1 | 8 | 14 | 0 | 23 |
| node-vulnerable | bibliothèques | 4 | 26 | 13 | 2 | 45 |
| node-fixed | système | 0 | 0 | 0 | 0 | 0 |
| node-fixed | bibliothèques | 1 | 19 | 6 | 3 | 29 |

Base vulnérable : `node:12-alpine`, Alpine 3.15.4.
Base corrigée : `node:20-alpine` avec `apk upgrade --no-cache`, Alpine 3.23.4.

## Lecture des résultats

La mise à jour de l'image de base supprime la totalité des vulnérabilités système, dont la seule
critique. C'est le résultat attendu par l'énoncé du TP.

Le périmètre des bibliothèques raconte une autre histoire. Le total baisse de 45 à 29, mais une
vulnérabilité critique subsiste, dans le paquet `tar` livré avec le npm de l'image officielle. Les
paquets `minimatch`, `brace-expansion`, `glob`, `cross-spawn` et `sigstore` complètent la liste.

## Analyse

- **Ce que la mise à jour de la base corrige** : l'intégralité de la couche Alpine, paquets système
  et bibliothèques C comprises.
- **Ce qui reste, et pourquoi** : les dépendances JavaScript embarquées dans l'image officielle.
  Elles ne dépendent ni de la distribution ni de `apk`, donc aucune commande de mise à jour système
  ne les touche.
- **Décision** : bloquer la chaîne d'intégration sur le périmètre système, qui doit rester à zéro,
  et traiter le périmètre applicatif séparément. Une image applicative réelle embarquerait son
  propre `package-lock.json`, dont les versions sont maîtrisées, contrairement au npm de base.

C'est exactement la raison d'être de l'analyse de composants en complément de l'analyse d'image :
deux outils, deux périmètres, deux façons de corriger.

## Comparaison avec la CI

Le même scan tourne dans GitHub Actions à chaque commit. Les chiffres y sont très proches, à
quelques vulnérabilités près sur les sévérités basses, la base de CVE de Trivy évoluant chaque jour.
