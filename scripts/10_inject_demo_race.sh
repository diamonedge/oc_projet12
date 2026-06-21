#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
source "${PROJECT_ROOT}/.env"
set +a

echo "============================================================"
echo "[ÉTAPE] INJECTION D'UNE COURSE DE DÉMONSTRATION"
echo "============================================================"

docker compose --project-directory "${PROJECT_ROOT}" exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 < "${PROJECT_ROOT}/sql/data/03_inject_demo_race.sql"

echo "============================================================"
echo "[ÉTAPE] RECALCUL DES MARTS DBT"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/06_check_and_run_dbt.sh"

echo "============================================================"
echo "[CONTRÔLE] ACTIVITÉ DE DÉMONSTRATION"
echo "============================================================"

docker compose --project-directory "${PROJECT_ROOT}" exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "
SELECT
    activity_id,
    employee_id,
    activity_start_datetime,
    sport_type,
    distance_meters,
    source_system
FROM marts.fct_sport_activities
WHERE activity_id = 900000001;
"

echo "============================================================"
echo "[CONTRÔLE] IMPACT DE LA RÉVISION DU TAUX"
echo "============================================================"

docker compose --project-directory "${PROJECT_ROOT}" exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "
SELECT
    calculation_as_of_date,
    bonus_rate,
    count(*) filter (
        where is_commute_bonus_eligible
    ) as eligible_employee_count,
    round(sum(annual_commute_bonus_gross), 2) as annual_commute_bonus_gross
FROM marts.mart_commute_bonus_eligibility
GROUP BY
    calculation_as_of_date,
    bonus_rate
ORDER BY calculation_as_of_date;
"
