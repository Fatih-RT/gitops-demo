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
printf '%-18s %8s %8s %8s %8s\n' IMAGE CRITICAL HIGH MEDIUM LOW
for image in node-vulnerable node-fixed; do
  read -r crit high med low < <(
    python3 - "rapports/${image}.json" <<'PY'
import json, sys
from collections import Counter
data = json.load(open(sys.argv[1]))
c = Counter()
for res in data.get("Results") or []:
    for v in res.get("Vulnerabilities") or []:
        c[v["Severity"]] += 1
print(c["CRITICAL"], c["HIGH"], c["MEDIUM"], c["LOW"])
PY
  )
  printf '%-18s %8s %8s %8s %8s\n' "${image}" "${crit}" "${high}" "${med}" "${low}"
done

echo
echo "Rapports complets dans trivy/rapports/ (non versionnes)."
