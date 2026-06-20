"""Simulation déterministe et injection brute d'activités sportives."""

from __future__ import annotations

import os
import random
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Final

import psycopg


DEFAULT_SIMULATION_SEED: Final[int] = 20260620
DEFAULT_REFERENCE_DATETIME: Final[str] = "2026-06-20T12:00:00"

HISTORY_DAYS: Final[int] = 365
MIN_ACTIVITIES_PER_EMPLOYEE: Final[int] = 12
MAX_ACTIVITIES_PER_EMPLOYEE: Final[int] = 42

SOURCE_FILE: Final[str] = "simulated_strava_activities.csv"
SOURCE_SYSTEM: Final[str] = "simulated_strava"

COMMENTS: Final[tuple[str, ...]] = (
    "",
    "",
    "",
    "Très bonne séance.",
    "Reprise du sport :)",
    "Belle sortie malgré le vent.",
    "Objectif régularité atteint.",
    "Séance avec des collègues.",
)


@dataclass(frozen=True)
class SportParameters:
    """Paramètres de simulation d'un sport."""

    min_distance_meters: int | None
    max_distance_meters: int | None
    min_speed_meters_per_second: float | None
    max_speed_meters_per_second: float | None
    min_duration_seconds: int
    max_duration_seconds: int


SPORT_PARAMETERS: Final[dict[str, SportParameters]] = {
    "Runing": SportParameters(2_000, 20_000, 2.0, 4.0, 0, 0),
    "Randonnée": SportParameters(3_000, 25_000, 1.0, 2.0, 0, 0),
    "Natation": SportParameters(500, 5_000, 0.6, 1.4, 0, 0),
    "Triathlon": SportParameters(10_000, 60_000, 3.0, 7.0, 0, 0),
    "Voile": SportParameters(2_000, 30_000, 2.0, 6.0, 0, 0),
    "Équitation": SportParameters(3_000, 20_000, 1.5, 4.0, 0, 0),
    "Escalade": SportParameters(None, None, None, None, 1_800, 10_800),
    "Tennis": SportParameters(None, None, None, None, 2_700, 7_200),
    "Football": SportParameters(None, None, None, None, 3_600, 7_200),
    "Rugby": SportParameters(None, None, None, None, 3_600, 7_200),
    "Badminton": SportParameters(None, None, None, None, 2_700, 5_400),
    "Judo": SportParameters(None, None, None, None, 3_600, 7_200),
    "Boxe": SportParameters(None, None, None, None, 3_600, 7_200),
    "Tennis de table": SportParameters(None, None, None, None, 2_700, 5_400),
    "Basketball": SportParameters(None, None, None, None, 3_600, 7_200),
}

DEFAULT_PARAMETERS: Final[SportParameters] = SportParameters(
    None,
    None,
    None,
    None,
    1_800,
    5_400,
)


def get_connection() -> psycopg.Connection:
    """Ouvre une connexion vers la base métier."""

    return psycopg.connect(
        host=os.environ["POSTGRES_HOST"],
        port=os.environ["POSTGRES_HOST_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_APP_USER"],
        password=os.environ["POSTGRES_APP_PASSWORD"],
    )


def get_simulation_parameters() -> tuple[int, datetime]:
    """Lit les paramètres déterministes de simulation."""

    seed = int(
        os.environ.get(
            "SIMULATION_SEED",
            str(DEFAULT_SIMULATION_SEED),
        )
    )

    reference_value = os.environ.get(
        "SIMULATION_REFERENCE_DATETIME",
        DEFAULT_REFERENCE_DATETIME,
    )

    reference_datetime = datetime.fromisoformat(reference_value)

    if reference_datetime.tzinfo is not None:
        raise ValueError(
            "SIMULATION_REFERENCE_DATETIME doit être une date sans fuseau "
            "horaire, par exemple 2026-06-20T12:00:00."
        )

    return seed, reference_datetime


def fetch_sport_profiles(
    cursor: psycopg.Cursor,
) -> list[tuple[str, str]]:
    """Lit les salariés ayant déclaré une pratique sportive."""

    cursor.execute(
        """
        SELECT
            employee_id,
            declared_sport
        FROM raw.employee_sport_profile_txt
        WHERE NULLIF(BTRIM(employee_id), '') IS NOT NULL
          AND NULLIF(BTRIM(declared_sport), '') IS NOT NULL
        ORDER BY employee_id;
        """
    )

    return [
        (str(employee_id), str(declared_sport))
        for employee_id, declared_sport in cursor.fetchall()
    ]


def generate_metrics(
    random_generator: random.Random,
    sport_type: str,
) -> tuple[str, str]:
    """Génère distance et durée, toujours sous forme textuelle."""

    parameters = SPORT_PARAMETERS.get(
        sport_type,
        DEFAULT_PARAMETERS,
    )

    if parameters.min_distance_meters is None:
        return (
            "",
            str(
                random_generator.randint(
                    parameters.min_duration_seconds,
                    parameters.max_duration_seconds,
                )
            ),
        )

    distance = random_generator.randint(
        parameters.min_distance_meters,
        parameters.max_distance_meters,
    )

    speed = random_generator.uniform(
        parameters.min_speed_meters_per_second,
        parameters.max_speed_meters_per_second,
    )

    elapsed_seconds = max(60, round(distance / speed))

    return str(distance), str(elapsed_seconds)


def generate_activity(
    random_generator: random.Random,
    activity_id: int,
    employee_id: str,
    sport_type: str,
    history_start: datetime,
    history_end: datetime,
) -> tuple[str, ...]:
    """Produit une activité brute dont la fin reste avant history_end."""

    distance_meters, elapsed_seconds = generate_metrics(
        random_generator,
        sport_type,
    )

    activity_duration = timedelta(seconds=int(elapsed_seconds))
    latest_start = history_end - activity_duration

    available_seconds = int(
        (latest_start - history_start).total_seconds()
    )

    if available_seconds < 0:
        raise RuntimeError(
            "La durée générée dépasse la fenêtre historique autorisée."
        )

    activity_start = history_start + timedelta(
        seconds=random_generator.randint(0, available_seconds)
    )
    activity_end = activity_start + activity_duration

    return (
        SOURCE_FILE,
        str(activity_id + 1),
        str(activity_id),
        employee_id,
        activity_start.isoformat(sep=" "),
        sport_type,
        distance_meters,
        activity_end.isoformat(sep=" "),
        elapsed_seconds,
        random_generator.choice(COMMENTS),
        SOURCE_SYSTEM,
    )


def generate_activities(
    sport_profiles: list[tuple[str, str]],
    seed: int,
    reference_datetime: datetime,
) -> list[tuple[str, ...]]:
    """Génère un historique déterministe couvrant douze mois."""

    random_generator = random.Random(seed)
    history_start = reference_datetime - timedelta(days=HISTORY_DAYS)

    rows: list[tuple[str, ...]] = []
    activity_id = 1

    for employee_id, sport_type in sport_profiles:
        activity_count = random_generator.randint(
            MIN_ACTIVITIES_PER_EMPLOYEE,
            MAX_ACTIVITIES_PER_EMPLOYEE,
        )

        for _ in range(activity_count):
            rows.append(
                generate_activity(
                    random_generator=random_generator,
                    activity_id=activity_id,
                    employee_id=employee_id,
                    sport_type=sport_type,
                    history_start=history_start,
                    history_end=reference_datetime,
                )
            )
            activity_id += 1

    return rows


def inject_activities(
    cursor: psycopg.Cursor,
    rows: list[tuple[str, ...]],
) -> None:
    """Remplace l'historique simulé avec COPY."""

    cursor.execute("TRUNCATE TABLE raw.sport_activities_txt;")

    copy_statement = """
        COPY raw.sport_activities_txt (
            source_file,
            source_row_number,
            activity_id,
            employee_id,
            activity_start_datetime,
            sport_type,
            distance_meters,
            activity_end_datetime,
            elapsed_seconds,
            activity_comment,
            source_system
        )
        FROM STDIN
    """

    with cursor.copy(copy_statement) as copy:
        for row in rows:
            copy.write_row(row)


def main() -> None:
    """Simule et injecte l'historique sportif brut."""

    simulation_seed, reference_datetime = get_simulation_parameters()

    with get_connection() as connection:
        with connection.transaction():
            with connection.cursor() as cursor:
                sport_profiles = fetch_sport_profiles(cursor)

                if not sport_profiles:
                    raise RuntimeError(
                        "Aucun profil sportif déclaré dans "
                        "raw.employee_sport_profile_txt."
                    )

                rows = generate_activities(
                    sport_profiles=sport_profiles,
                    seed=simulation_seed,
                    reference_datetime=reference_datetime,
                )

                inject_activities(cursor, rows)

    print(
        "[SUCCÈS] Simulation et injection terminées : "
        f"{len(rows)} activités sportives générées."
    )
    print(f"[INFO] Graine utilisée : {simulation_seed}")
    print(
        "[INFO] Date de référence : "
        f"{reference_datetime.isoformat(sep=' ')}"
    )


if __name__ == "__main__":
    main()
