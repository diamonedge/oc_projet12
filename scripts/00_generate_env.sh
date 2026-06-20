#!/bin/sh
test ! -e .env || { echo ".env existe déjà : arrêt."; exit 1; }

secret() {
  uv run python -c "import secrets; print(secrets.token_urlsafe(32))"
}

cat > .env <<EOF
POSTGRES_HOST=127.0.0.1
POSTGRES_HOST_PORT=5433

POSTGRES_DB=sport_benefits

POSTGRES_USER=sport_benefits_owner
POSTGRES_PASSWORD=$(secret)

POSTGRES_APP_USER=sport_benefits_app
POSTGRES_APP_PASSWORD=$(secret)
EOF

chmod 600 .env
