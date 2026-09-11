# TP3 — Relevé des scans Trivy

Tableau à compléter avec la sortie de `./trivy/scan.sh` exécuté sur la VM Ubuntu.
Les rapports complets se trouvent dans `trivy/rapports/` (dossier non versionné).

## Décompte par sévérité

| Image | Base | CRITICAL | HIGH | MEDIUM | LOW | Total |
| --- | --- | --- | --- | --- | --- | --- |
| node-vulnerable | node:12-alpine | | | | | |
| node-fixed | node:20-alpine + apk upgrade | | | | | |

Séparer les deux périmètres, car ils ne se corrigent pas de la même façon :

| Image | Paquets système | Bibliothèques embarquées |
| --- | --- | --- |
| node-vulnerable | | |
| node-fixed | | |

Relevé de la CI du 11 septembre 2026 sur `node-fixed` : 0 CRITICAL et 0 HIGH côté système
(Alpine 3.23.4), mais 1 CRITICAL et 19 HIGH côté bibliothèques npm embarquées.

Version de Trivy utilisée : `trivy --version` → ...
Date du scan : ...

## Vulnérabilités critiques de l'image vulnérable

| CVE | Paquet | Version installée | Version corrigée | Commentaire |
| --- | --- | --- | --- | --- |
| | | | | |

## Analyse

- Ce que la mise à jour de la base corrige :
- Ce qui reste après correction, et pourquoi (`will_not_fix`, pas de correctif amont) :
- Décision prise pour le résiduel (acceptation documentée, changement de base, suppression du paquet) :
