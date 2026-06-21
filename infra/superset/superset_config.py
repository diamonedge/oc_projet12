"""Configuration locale Apache Superset du projet Sport Data Solution."""

from __future__ import annotations

import os
from urllib.parse import quote_plus


def required_environment_variable(name: str) -> str:
    """Retourne une variable obligatoire et refuse les valeurs de démonstration."""

    value = os.environ.get(name, "").strip()

    if not value or value == "change_me":
        raise RuntimeError(
            f"La variable d'environnement {name} doit être configurée."
        )

    return value


metadata_user = required_environment_variable("SUPERSET_METADATA_USER")
metadata_password = required_environment_variable(
    "SUPERSET_METADATA_PASSWORD"
)
metadata_database = required_environment_variable("SUPERSET_METADATA_DB")

SQLALCHEMY_DATABASE_URI = (
    "postgresql+psycopg2://"
    f"{quote_plus(metadata_user)}:{quote_plus(metadata_password)}"
    f"@postgres:5432/{quote_plus(metadata_database)}"
)

SECRET_KEY = required_environment_variable("SUPERSET_SECRET_KEY")

WTF_CSRF_ENABLED = True
SQLALCHEMY_TRACK_MODIFICATIONS = False
