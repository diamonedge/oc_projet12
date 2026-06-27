#!/usr/bin/env bash

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
      -tAX \
      -v ON_ERROR_STOP=1 \
      -c "$1"
}

assert_value() {
  local label="$1"
  local expected="$2"
  local query="$3"
  local actual

  actual="$(run_psql "${query}")"

  if [[ "${actual}" != "${expected}" ]]; then
    echo "[ERREUR] ${label}" >&2
    echo "  attendu : ${expected}" >&2
    echo "  obtenu  : ${actual}" >&2
    exit 1
  fi

  echo "[SUCCÈS] ${label} : ${actual}"
}

echo "============================================================"
echo "[CONTRÔLE] SERVICES"
echo "============================================================"

curl --fail --silent --show-error \
  "http://127.0.0.1:8081/health/readiness" > /dev/null

curl --fail --silent --show-error \
  "http://127.0.0.1:${SUPERSET_HOST_PORT}/health" > /dev/null

echo "[SUCCÈS] Kestra disponible."
echo "[SUCCÈS] Superset disponible."

echo "============================================================"
echo "[CONTRÔLE] DONNÉES ET MARTS"
echo "============================================================"

assert_value \
  "Salariés injectés" \
  "161" \
  "SELECT count(*) FROM raw.hr_employees_txt;"

assert_value \
  "Profils sportifs injectés" \
  "161" \
  "SELECT count(*) FROM raw.employee_sport_profile_txt;"

assert_value \
  "Activités simulées" \
  "2473" \
  "SELECT count(*) FROM raw.sport_activities_txt;"

assert_value \
  "Réponses Google Routes" \
  "68" \
  "SELECT count(*) FROM raw.google_routes_responses_txt;"

assert_value \
  "Activités dans le mart" \
  "2473" \
  "SELECT count(*) FROM marts.fct_sport_activities;"

assert_value \
  "État métier initial" \
  "2026-06-20|0.05|68|172482.50" \
  "
  SELECT concat_ws(
      '|',
      calculation_as_of_date::text,
      bonus_rate::text,
      count(*) FILTER (
          WHERE is_commute_bonus_eligible
      )::text,
      round(sum(annual_commute_bonus_gross), 2)::text
  )
  FROM marts.mart_commute_bonus_eligibility
  GROUP BY
      calculation_as_of_date,
      bonus_rate;
  "

assert_value \
  "Historique Slack classé BACKFILLED" \
  "2473" \
  "
  SELECT count(*)
  FROM ops.slack_publication_queue
  WHERE publication_status = 'BACKFILLED';
  "

echo "============================================================"
echo "[SUCCÈS] LIVRABLE PRÊT POUR LA DÉMONSTRATION"
echo "============================================================"
