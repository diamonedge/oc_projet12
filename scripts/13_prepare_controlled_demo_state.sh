#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
source "${PROJECT_ROOT}/.env"
set +a

run_psql() {
  docker compose \
    --project-directory "${PROJECT_ROOT}" \
    exec -T postgres \
    psql \
      -U "${POSTGRES_USER}" \
      -d "${POSTGRES_DB}" \
      -v ON_ERROR_STOP=1 \
      "$@"
}

echo "============================================================"
echo "[DÉMONSTRATION] PRÉPARATION D'UN ÉTAT CONTRÔLÉ"
echo "============================================================"

echo "============================================================"
echo "[ÉTAPE 1] CRÉATION DES OBJETS POSTGRESQL"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/01_create_tables.sh"

echo "============================================================"
echo "[ÉTAPE 2] REMISE À ZÉRO DES DONNÉES MÉTIER"
echo "============================================================"

run_psql < "${PROJECT_ROOT}/sql/operations/03_reset_demo_state.sql"

echo "============================================================"
echo "[ÉTAPE 3] INJECTION DES SOURCES RH ET SPORTIVES"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/02_inject_sources.sh"

echo "============================================================"
echo "[ÉTAPE 4] INJECTION DES PARAMÈTRES INITIAUX"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/03_inject_benefit_parameters.sh"

echo "============================================================"
echo "[ÉTAPE 5] INJECTION DES ACTIVITÉS SIMULÉES"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/04_inject_simulated_activities.sh"

echo "============================================================"
echo "[ÉTAPE 6] INJECTION DES RÉPONSES GOOGLE ROUTES"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/05_inject_google_routes.sh"

echo "============================================================"
echo "[ÉTAPE 7] TRANSFORMATIONS ET CONTRÔLES DBT"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/06_check_and_run_dbt.sh"

echo "============================================================"
echo "[ÉTAPE 8] SYNCHRONISATION DE LA FILE SLACK"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/07_sync_slack_publication_queue.sh"

echo "============================================================"
echo "[ÉTAPE 9] CLASSEMENT DE L'HISTORIQUE SLACK"
echo "============================================================"

run_psql -v pending_batch_size=0 < "${PROJECT_ROOT}/sql/operations/02_mark_initial_slack_backfill.sql"

echo "============================================================"
echo "[CONTRÔLE] ÉTAT INITIAL DE LA DÉMONSTRATION"
echo "============================================================"

run_psql -c "
SELECT
    calculation_as_of_date,
    bonus_rate,
    count(*) FILTER (
        WHERE is_commute_bonus_eligible
    ) AS eligible_employee_count,
    round(sum(annual_commute_bonus_gross), 2) AS annual_commute_bonus_gross
FROM marts.mart_commute_bonus_eligibility
GROUP BY
    calculation_as_of_date,
    bonus_rate
ORDER BY
    calculation_as_of_date;
"

run_psql -c "
SELECT
    publication_status,
    count(*) AS activity_count
FROM ops.slack_publication_queue
GROUP BY publication_status
ORDER BY publication_status;
"

echo "============================================================"
echo "[SUCCÈS] ÉTAT INITIAL CONTRÔLÉ PRÊT POUR LA DÉMONSTRATION"
echo "============================================================"
