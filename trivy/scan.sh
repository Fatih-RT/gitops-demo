#!/usr/bin/env bash
# TP3 - Build + scan Trivy des deux images, puis comparaison.
# Usage : ./trivy/scan.sh
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p rapports

echo "==> Build de l'image vulnerable"
docker build -t node-vulnerable -f Dockerfile.vulnerable .

echo "==> Build de l'image corrigee"
docker build -t node-fixed -f Dockerfile.fixed .

for image in node-vulnerable node-fixed; do
  echo "==> Scan Trivy : ${image}"
  sudo trivy image --scanners vuln "${image}" | tee "rapports/${image}.txt"
  sudo trivy image --scanners vuln --format json --output "rapports/${image}.json" "${image}"
done

echo
echo "==> Comparaison du nombre de vulnerabilites par severite"
echo "    (systeme = paquets Alpine, bibliotheques = dependances embarquees type npm)"
for image in node-vulnerable node-fixed; do
  python3 - "rapports/${image}.json" "${image}" <<'PY'
import json, sys
from collections import Counter

data = json.load(open(sys.argv[1]))
image = sys.argv[2]
counts = {"systeme": Counter(), "bibliotheques": Counter()}

for res in data.get("Results") or []:
    groupe = "systeme" if res.get("Class") == "os-pkgs" else "bibliotheques"
    for v in res.get("Vulnerabilities") or []:
        counts[groupe][v["Severity"]] += 1

print(f"\n{image}")
print(f"{'PERIMETRE':<16}{'CRITICAL':>10}{'HIGH':>8}{'MEDIUM':>8}{'LOW':>8}")
for groupe, c in counts.items():
    print(f"{groupe:<16}{c['CRITICAL']:>10}{c['HIGH']:>8}{c['MEDIUM']:>8}{c['LOW']:>8}")
PY
done

echo
echo "Rapports complets dans trivy/rapports/ (non versionnes)."
