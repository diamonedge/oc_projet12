#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
source "${PROJECT_ROOT}/.env"
set +a

echo "============================================================"
echo "[ÉTAPE] TEST GOOGLE ROUTES : UN TRAJET SPORTIF"
echo "============================================================"

cd "${PROJECT_ROOT}"

uv run python -m src.sport_data_solution.inject_google_routes "$@"
