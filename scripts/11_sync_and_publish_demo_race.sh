#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_ACTIVITY_ID="900000001"

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
echo "[ÉTAPE] SYNCHRONISATION DE LA COURSE DE DÉMONSTRATION"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/07_sync_slack_publication_queue.sh"

other_pending_count="$(
  run_psql -tAX -c "
    SELECT count(*)
    FROM ops.slack_publication_queue
    WHERE publication_status = 'PENDING'
      AND activity_id <> ${DEMO_ACTIVITY_ID};
  "
)"

if [[ "${other_pending_count}" != "0" ]]; then
  echo "[ERREUR] ${other_pending_count} activité(s) historique(s) sont encore PENDING." >&2
  echo "[ERREUR] La publication de démonstration est interrompue." >&2
  exit 1
fi

demo_status="$(
  run_psql -tAX -c "
    SELECT publication_status
    FROM ops.slack_publication_queue
    WHERE activity_id = ${DEMO_ACTIVITY_ID};
  "
)"

if [[ "${demo_status}" != "PENDING" ]]; then
  echo "[ERREUR] L'activité ${DEMO_ACTIVITY_ID} doit être PENDING, statut actuel : ${demo_status:-absent}." >&2
  exit 1
fi

echo "============================================================"
echo "[ÉTAPE] PUBLICATION SLACK DE LA COURSE DE DÉMONSTRATION"
echo "============================================================"

bash "${PROJECT_ROOT}/scripts/08_publish_slack_activities.sh" --limit 1

echo "============================================================"
echo "[CONTRÔLE] ÉTAT DURABLE DE LA COURSE DE DÉMONSTRATION"
echo "============================================================"

run_psql -c "
  SELECT
      activity_id,
      publication_status,
      attempt_count,
      slack_message_ts,
      slack_permalink,
      last_error
  FROM ops.slack_publication_queue
  WHERE activity_id = ${DEMO_ACTIVITY_ID};
"
