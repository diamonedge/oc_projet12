#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
source "${PROJECT_ROOT}/.env"
set +a

export POSTGRES_HOST="${POSTGRES_HOST_OVERRIDE:-${POSTGRES_HOST}}"
export POSTGRES_HOST_PORT="${POSTGRES_HOST_PORT_OVERRIDE:-${POSTGRES_HOST_PORT}}"
export UV_LINK_MODE="${UV_LINK_MODE:-copy}"

SLACK_PUBLICATION_BATCH_SIZE="${SLACK_PUBLICATION_BATCH_SIZE:-40}"

if ! [[ "${SLACK_PUBLICATION_BATCH_SIZE}" =~ ^[1-9][0-9]*$ ]]; then
  echo "[ERREUR] SLACK_PUBLICATION_BATCH_SIZE doit être un entier strictement positif." >&2
  exit 1
fi

has_limit_argument=false

for argument in "$@"; do
  case "${argument}" in
    --limit|--limit=*)
      has_limit_argument=true
      break
      ;;
  esac
done

if [[ "${has_limit_argument}" == "false" ]]; then
  set -- --limit "${SLACK_PUBLICATION_BATCH_SIZE}" "$@"
fi

echo "============================================================"
echo "[ÉTAPE] PUBLICATION DES ACTIVITÉS SPORTIVES DANS SLACK"
echo "============================================================"
echo "[PARAMÈTRE] Taille maximale du lot : ${SLACK_PUBLICATION_BATCH_SIZE}"

cd "${PROJECT_ROOT}"

uv run python -m src.sport_data_solution.publish_slack_activities "$@"
