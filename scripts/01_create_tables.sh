#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${PROJECT_ROOT}/infra/kestra/.env" ]]; then
  bash "${PROJECT_ROOT}/scripts/00_generate_kestra_env.sh"
fi

set -a
source "${PROJECT_ROOT}/.env"
source "${PROJECT_ROOT}/infra/kestra/.env"
set +a

run_psql() {
  docker compose \
    --project-directory "${PROJECT_ROOT}" \
    exec -T postgres \
    psql \
      "$@"
}

run_main_database_psql() {
  run_psql \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    -v ON_ERROR_STOP=1 \
    "$@"
}

echo "============================================================"
echo "[ÉTAPE] CRÉATION DES OBJETS POSTGRESQL"
echo "============================================================"

run_main_database_psql \
  -v app_user="${POSTGRES_APP_USER}" \
  < "${PROJECT_ROOT}/sql/init/01_create_raw_tables.sql"

run_main_database_psql \
  -v app_user="${POSTGRES_APP_USER}" \
  < "${PROJECT_ROOT}/sql/init/02_create_raw_sport_activities.sql"

run_main_database_psql \
  -v app_user="${POSTGRES_APP_USER}" \
  < "${PROJECT_ROOT}/sql/init/04_create_raw_benefit_parameters.sql"

run_main_database_psql \
  -v app_user="${POSTGRES_APP_USER}" \
  < "${PROJECT_ROOT}/sql/init/05_create_raw_google_routes_responses.sql"

run_main_database_psql \
  -v dbt_user="${POSTGRES_DBT_USER}" \
  -v dbt_password="${POSTGRES_DBT_PASSWORD}" \
  -v db_owner="${POSTGRES_USER}" \
  < "${PROJECT_ROOT}/sql/init/03_create_dbt_role_and_schemas.sql"

run_main_database_psql \
  -v superset_metadata_user="${SUPERSET_METADATA_USER}" \
  -v superset_metadata_password="${SUPERSET_METADATA_PASSWORD}" \
  -v superset_reader_user="${SUPERSET_READER_USER}" \
  -v superset_reader_password="${SUPERSET_READER_PASSWORD}" \
  -v superset_metadata_db="${SUPERSET_METADATA_DB}" \
  -v dbt_user="${POSTGRES_DBT_USER}" \
  < "${PROJECT_ROOT}/sql/init/06_create_superset_roles_and_metadata.sql"

run_main_database_psql \
  -v app_user="${POSTGRES_APP_USER}" \
  < "${PROJECT_ROOT}/sql/init/07_create_ops_slack_publication_queue.sql"

echo "============================================================"
echo "[ÉTAPE] CRÉATION DES MÉTADONNÉES KESTRA"
echo "============================================================"

run_psql \
  -U "${POSTGRES_USER}" \
  -d postgres \
  -v ON_ERROR_STOP=1 \
  -v kestra_metadata_db="${KESTRA_METADATA_DB}" \
  -v kestra_metadata_user="${KESTRA_METADATA_USER}" \
  -v kestra_metadata_password="${KESTRA_METADATA_PASSWORD}" \
  < "${PROJECT_ROOT}/sql/init/08_create_kestra_metadata.sql"
