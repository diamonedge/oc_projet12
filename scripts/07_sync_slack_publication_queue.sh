#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
source "${PROJECT_ROOT}/.env"
set +a

echo "============================================================"
echo "[ÉTAPE] SYNCHRONISATION DE LA FILE DE PUBLICATION SLACK"
echo "============================================================"

docker compose --project-directory "${PROJECT_ROOT}" exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 < "${PROJECT_ROOT}/sql/operations/01_sync_slack_publication_queue.sql"

echo "[SUCCÈS] File Slack synchronisée."
