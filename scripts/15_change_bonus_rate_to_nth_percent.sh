#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
source "${PROJECT_ROOT}/.env"
set +a

TAUX_REVISE=$1

echo "============================================================"
echo "[ÉTAPE] RÉVISION DU TAUX DE PRIME À $TAUX_REVISE %"
echo "============================================================"

docker compose \
  --project-directory "${PROJECT_ROOT}" \
  exec -T postgres \
  psql \
    --variable=bonus_rate=$TAUX_REVISE \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    -v ON_ERROR_STOP=1 \
  < "${PROJECT_ROOT}/sql/data/04_change_bonus_rate_to_nth_percent.sql"

echo "------------------------------------------------------------"
echo "[CONTRÔLE] Historique du paramètre bonus_rate"
echo "------------------------------------------------------------"

docker compose --project-directory "${PROJECT_ROOT}" exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "
SELECT
    parameter_value AS bonus_rate,
    valid_from,
    NULLIF(valid_to, '') AS valid_to,
    parameter_comment
FROM raw.benefit_parameters_txt
WHERE parameter_name = 'bonus_rate'
ORDER BY valid_from;
"
