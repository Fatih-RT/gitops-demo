# Repères DevSecOps — cours et panorama d'outils

Synthèse personnelle du cours d'introduction et de la liste d'outils du module, resituée par rapport
aux trois TP de ce dépôt.

## De DevOps à DevSecOps

DevOps cherche la vitesse et la fiabilité par l'automatisation. Le défaut du modèle est que la
sécurité arrive en fin de cycle, souvent après la mise en production. DevSecOps déplace les
contrôles vers le début de la chaîne, approche dite *shift left*, et fait de la sécurité une
responsabilité partagée entre développement, exploitation et sécurité.

| Aspect | DevOps | DevSecOps |
| --- | --- | --- |
| Objectif | rapidité de livraison | rapidité et sécurité |
| Sécurité | ajoutée en fin de cycle | intégrée dès la conception |
| Acteurs | Dev + Ops | Dev + Ops + Sec |
| Pipeline | Build → Test → Deploy | Build → Test sécurisé → Deploy |

Risques typiques traités par la démarche : images de conteneurs vulnérables, secrets laissés dans un
dépôt Git, configurations Kubernetes trop permissives (RBAC, ports ouverts).

## Ce que couvrent les TP

| Étape du pipeline | Contrôle | TP correspondant |
| --- | --- | --- |
| Build | scan des dépendances et des images | TP3, Trivy |
| Deploy | livraison déclarative et tracée | TP1 et TP2, ArgoCD |
| Run | état du cluster réconcilié en continu | TP2, `selfHeal` |

## Panorama d'outils par catégorie

**Planification et documentation** : Jira pour le suivi, Confluence pour les politiques de sécurité
et les modèles de menace.

**Code source et analyse statique** : GitHub et GitLab intègrent l'analyse de code et la détection
de secrets. SonarQube fait de l'analyse statique approfondie, Semgrep une analyse rapide par règles
personnalisables.

**Analyse des composants (SCA)** : Snyk couvre dépendances, images et infrastructure as code.
OWASP Dependency-Check identifie les composants vulnérables à partir de la base NVD.

**Secrets et politiques** : HashiCorp Vault pour la gestion centralisée des secrets, les coffres
gérés des fournisseurs cloud (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager) pour la
rotation et l'audit, Open Policy Agent et Kyverno pour la politique sous forme de code.

**CI/CD et GitOps** : Argo CD et Flux pour la livraison déclarative sur Kubernetes, GitHub Actions,
GitLab CI et CircleCI pour les pipelines avec portes de sécurité.

**Tests dynamiques et détection** : OWASP ZAP et Burp Suite pour l'analyse d'applications en cours
d'exécution, Trivy pour les conteneurs, le code et l'infrastructure as code, Checkov pour les
erreurs de configuration Terraform et Kubernetes, Falco pour la détection d'anomalies à l'exécution.

**Observabilité et SIEM** : la pile ELK pour la centralisation des journaux, Splunk et Datadog pour
la corrélation, les alertes et les tableaux de bord de conformité.

## Flux de référence

1. le développeur pousse son code sur GitHub ;
2. la CI construit l'image ;
3. l'image est analysée avec Trivy ;
4. le code est analysé avec SonarQube ou Semgrep ;
5. si les contrôles passent, ArgoCD déploie sur Kubernetes ;
6. la surveillance continue prend le relais (Prometheus, Falco).

## Points de vigilance

Les gains sont réels : détection précoce, coût de correction plus faible, conformité facilitée
(RGPD, ISO 27001). Les difficultés le sont aussi : montée en compétences, risque de ralentissement
si les analyses sont trop longues ou génèrent trop de faux positifs, et surtout transformation
culturelle. DevSecOps est d'abord une pratique partagée, pas une liste d'outils.
