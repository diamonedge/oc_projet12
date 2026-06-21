#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
source "${PROJECT_ROOT}/.env"
set +a

export UV_LINK_MODE="${UV_LINK_MODE:-copy}"

GOOGLE_ROUTES_BATCH_SIZE="${GOOGLE_ROUTES_BATCH_SIZE:-100}"

if ! [[ "${GOOGLE_ROUTES_BATCH_SIZE}" =~ ^[1-9][0-9]*$ ]]; then
  echo "[ERREUR] GOOGLE_ROUTES_BATCH_SIZE doit être un entier strictement positif." >&2
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
  set -- --limit "${GOOGLE_ROUTES_BATCH_SIZE}" "$@"
fi

echo "============================================================"
echo "[ÉTAPE] INJECTION DES RÉPONSES GOOGLE ROUTES"
echo "============================================================"
echo "[PARAMÈTRE] Taille maximale du lot : ${GOOGLE_ROUTES_BATCH_SIZE}"

cd "${PROJECT_ROOT}"

uv run python -m src.sport_data_solution.inject_google_routes "$@"
