"""Appel Google Routes et injection brute des réponses dans PostgreSQL."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Final

import psycopg
import requests


OFFICE_ADDRESS: Final[str] = "1362 Av. des Platanes, 34970 Lattes"
ROUTES_URL: Final[str] = (
    "https://routes.googleapis.com/directions/v2:computeRoutes"
)
FIELD_MASK: Final[str] = "routes.distanceMeters,routes.duration"
SOURCE_FILE: Final[str] = "google_routes_api"

COMMUTE_MODE_MAPPING: Final[dict[str, str]] = {
    "Marche/running": "WALK",
    "Vélo/Trottinette/Autres": "BICYCLE",
}


@dataclass(frozen=True)
class RouteCandidate:
    """Trajet à soumettre à Google Routes."""

    source_row_number: str
    employee_id: str
    home_address: str
    declared_commute_mode: str
    google_travel_mode: str
    request_key: str


def get_connection() -> psycopg.Connection:
    """Ouvre une connexion PostgreSQL avec le rôle applicatif."""

    return psycopg.connect(
        host=os.environ["POSTGRES_HOST"],
        port=os.environ["POSTGRES_HOST_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_APP_USER"],
        password=os.environ["POSTGRES_APP_PASSWORD"],
    )


def build_request_key(
    employee_id: str,
    home_address: str,
    declared_commute_mode: str,
    google_travel_mode: str,
) -> str:
    """Construit une clé déterministe pour une requête Google Routes."""

    key_material = "|".join(
        (
            employee_id.strip(),
            home_address.strip(),
            OFFICE_ADDRESS,
            declared_commute_mode.strip(),
            google_travel_mode,
        )
    )

    return hashlib.sha256(key_material.encode("utf-8")).hexdigest()


def fetch_existing_request_keys(cursor: psycopg.Cursor) -> set[str]:
    """Retourne les requêtes déjà conservées dans la couche brute."""

    cursor.execute(
        """
        SELECT DISTINCT request_key
        FROM raw.google_routes_responses_txt
        WHERE request_key IS NOT NULL;
        """
    )

    return {
        str(request_key)
        for (request_key,) in cursor.fetchall()
    }


def fetch_candidates(
    cursor: psycopg.Cursor,
    limit: int,
) -> list[RouteCandidate]:
    """Lit les trajets sportifs non encore traités."""

    cursor.execute(
        """
        SELECT
            source_row_number,
            employee_id,
            home_address,
            commute_mode
        FROM raw.hr_employees_txt
        WHERE BTRIM(commute_mode) = ANY(%s)
          AND NULLIF(BTRIM(employee_id), '') IS NOT NULL
          AND NULLIF(BTRIM(home_address), '') IS NOT NULL
        ORDER BY employee_id;
        """,
        (list(COMMUTE_MODE_MAPPING),),
    )

    source_rows = cursor.fetchall()
    existing_request_keys = fetch_existing_request_keys(cursor)

    candidates: list[RouteCandidate] = []

    for source_row_number, employee_id, home_address, commute_mode in source_rows:
        declared_commute_mode = str(commute_mode).strip()
        google_travel_mode = COMMUTE_MODE_MAPPING[declared_commute_mode]

        request_key = build_request_key(
            employee_id=str(employee_id),
            home_address=str(home_address),
            declared_commute_mode=declared_commute_mode,
            google_travel_mode=google_travel_mode,
        )

        if request_key in existing_request_keys:
            continue

        candidates.append(
            RouteCandidate(
                source_row_number=str(source_row_number),
                employee_id=str(employee_id).strip(),
                home_address=str(home_address).strip(),
                declared_commute_mode=declared_commute_mode,
                google_travel_mode=google_travel_mode,
                request_key=request_key,
            )
        )

    return candidates[:limit]


def build_payload(candidate: RouteCandidate) -> dict[str, object]:
    """Construit le corps JSON attendu par Google Routes."""

    return {
        "origin": {"address": candidate.home_address},
        "destination": {"address": OFFICE_ADDRESS},
        "travelMode": candidate.google_travel_mode,
        "languageCode": "fr-FR",
        "units": "METRIC",
    }


def request_route(
    api_key: str,
    payload: dict[str, object],
) -> tuple[str, str]:
    """Appelle Google Routes et retourne le statut et la réponse brute."""

    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": api_key,
        "X-Goog-FieldMask": FIELD_MASK,
    }

    try:
        response = requests.post(
            ROUTES_URL,
            headers=headers,
            json=payload,
            timeout=30,
        )
    except requests.RequestException as error:
        return (
            "REQUEST_ERROR",
            json.dumps(
                {"request_error": str(error)},
                ensure_ascii=False,
            ),
        )

    try:
        response_payload = response.json()
    except ValueError:
        response_payload = {"raw_response": response.text}

    if response.status_code == 200 and not response_payload.get("routes"):
        return (
            "NO_ROUTE",
            json.dumps(
                response_payload,
                ensure_ascii=False,
                sort_keys=True,
            ),
        )

    return (
        str(response.status_code),
        json.dumps(
            response_payload,
            ensure_ascii=False,
            sort_keys=True,
        ),
    )


def inject_raw_response(
    cursor: psycopg.Cursor,
    candidate: RouteCandidate,
    request_payload_json: str,
    response_http_status: str,
    response_payload_json: str,
) -> None:
    """Injecte une réponse Google brute avec COPY."""

    requested_at = datetime.now(timezone.utc).isoformat()

    copy_statement = """
        COPY raw.google_routes_responses_txt (
            source_file,
            source_row_number,
            request_key,
            employee_id,
            home_address,
            office_address,
            declared_commute_mode,
            google_travel_mode,
            request_payload_json,
            response_http_status,
            response_payload_json,
            requested_at
        )
        FROM STDIN
    """

    with cursor.copy(copy_statement) as copy:
        copy.write_row(
            (
                SOURCE_FILE,
                candidate.source_row_number,
                candidate.request_key,
                candidate.employee_id,
                candidate.home_address,
                OFFICE_ADDRESS,
                candidate.declared_commute_mode,
                candidate.google_travel_mode,
                request_payload_json,
                response_http_status,
                response_payload_json,
                requested_at,
            )
        )


def parse_arguments() -> argparse.Namespace:
    """Lit les paramètres d'exécution."""

    parser = argparse.ArgumentParser(
        description=(
            "Calcule et injecte des trajets domicile-bureau "
            "avec Google Routes."
        )
    )

    parser.add_argument(
        "--limit",
        type=int,
        default=1,
        help="Nombre maximal de trajets inédits à traiter.",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Affiche les trajets sans effectuer d'appel API.",
    )

    return parser.parse_args()


def main() -> int:
    """Exécute les appels Google Routes et l'injection brute."""

    arguments = parse_arguments()

    if arguments.limit <= 0:
        raise ValueError("--limit doit être strictement positif.")

    with get_connection() as connection:
        with connection.cursor() as cursor:
            candidates = fetch_candidates(
                cursor=cursor,
                limit=arguments.limit,
            )

            if not candidates:
                print("[INFO] Aucun trajet inédit à traiter.")
                return 0

            if arguments.dry_run:
                for candidate in candidates:
                    print(
                        "[DRY-RUN] "
                        f"employee_id={candidate.employee_id} "
                        f"mode={candidate.google_travel_mode}"
                    )

                print(
                    f"[INFO] Trajets inédits détectés : {len(candidates)}."
                )
                return 0

            api_key = os.environ.get("GOOGLE_MAPS_API_KEY", "").strip()

            if not api_key or api_key == "change_me":
                raise RuntimeError(
                    "GOOGLE_MAPS_API_KEY est absente ou non configurée."
                )

            failures = 0

            for candidate in candidates:
                payload = build_payload(candidate)
                request_payload_json = json.dumps(
                    payload,
                    ensure_ascii=False,
                    sort_keys=True,
                )

                response_http_status, response_payload_json = request_route(
                    api_key=api_key,
                    payload=payload,
                )

                inject_raw_response(
                    cursor=cursor,
                    candidate=candidate,
                    request_payload_json=request_payload_json,
                    response_http_status=response_http_status,
                    response_payload_json=response_payload_json,
                )

                print(
                    "[INFO] "
                    f"employee_id={candidate.employee_id} "
                    f"mode={candidate.google_travel_mode} "
                    f"http_status={response_http_status}"
                )

                if not response_http_status.startswith("2"):
                    failures += 1

        connection.commit()

    if failures:
        print(
            "[ERREUR] Certaines réponses sont en échec ; "
            "elles sont conservées dans raw."
        )
        return 1

    print(f"[SUCCÈS] Réponses Google Routes injectées : {len(candidates)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
