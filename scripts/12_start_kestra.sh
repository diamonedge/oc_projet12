#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================================"
echo "[ÉTAPE] INITIALISATION DES MÉTADONNÉES KESTRA"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/01_create_tables.sh"

echo "============================================================"
echo "[ÉTAPE] DÉMARRAGE DE KESTRA"
echo "============================================================"

docker compose \
  --project-directory "${PROJECT_ROOT}" \
  up -d kestra

echo "============================================================"
echo "[CONTRÔLE] DISPONIBILITÉ DE KESTRA"
echo "============================================================"

for attempt in $(seq 1 30); do
  if curl --fail --silent --show-error \
    "http://127.0.0.1:8081/health/readiness"; then
    printf "\n[SUCCÈS] Kestra est disponible sur http://127.0.0.1:8080\n"
    exit 0
  fi

  sleep 2
done

echo "[ERREUR] Kestra ne répond pas après 60 secondes." >&2

docker compose \
  --project-directory "${PROJECT_ROOT}" \
  logs \
  --tail=200 \
  kestra >&2

exit 1
