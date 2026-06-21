#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KESTRA_ENV_FILE="${PROJECT_ROOT}/infra/kestra/.env"

if [[ -e "${KESTRA_ENV_FILE}" ]]; then
  echo "[INFO] ${KESTRA_ENV_FILE} existe déjà : aucune régénération."
  exit 0
fi

generate_secret() {
  uv run python -c "import secrets; print(secrets.token_urlsafe(32))"
}

mkdir -p "${PROJECT_ROOT}/infra/kestra"

cat > "${KESTRA_ENV_FILE}" <<EOF
KESTRA_ADMIN_USERNAME=kestra_admin
KESTRA_ADMIN_PASSWORD=$(generate_secret)
KESTRA_METADATA_DB=kestra_meta
KESTRA_METADATA_USER=kestra_meta
KESTRA_METADATA_PASSWORD=$(generate_secret)
EOF

chmod 600 "${KESTRA_ENV_FILE}"

echo "[SUCCÈS] Fichier de configuration Kestra créé : ${KESTRA_ENV_FILE}"
