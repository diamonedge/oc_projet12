"""Injection brute des fichiers Excel vers les tables raw PostgreSQL."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Final

import pandas as pd
import psycopg


INPUT_DIR: Final[Path] = Path("data/input")


@dataclass(frozen=True)
class SourceSpec:
    """Contrat technique d'injection d'un fichier source."""

    file_name: str
    raw_table: str
    source_columns: tuple[str, ...]
    target_columns: tuple[str, ...]


SOURCES: Final[tuple[SourceSpec, ...]] = (
    SourceSpec(
        file_name="Données+RH.xlsx",
        raw_table="raw.hr_employees_txt",
        source_columns=(
            "ID salarié",
            "Nom",
            "Prénom",
            "Date de naissance",
            "BU",
            "Date d'embauche",
            "Salaire brut",
            "Type de contrat",
            "Nombre de jours de CP",
            "Adresse du domicile",
            "Moyen de déplacement",
        ),
        target_columns=(
            "employee_id",
            "last_name",
            "first_name",
            "birth_date",
            "business_unit",
            "hire_date",
            "gross_salary",
            "contract_type",
            "paid_leave_days",
            "home_address",
            "commute_mode",
        ),
    ),
    SourceSpec(
        file_name="Données+Sportive.xlsx",
        raw_table="raw.employee_sport_profile_txt",
        source_columns=(
            "ID salarié",
            "Pratique d'un sport",
        ),
        target_columns=(
            "employee_id",
            "declared_sport",
        ),
    ),
)


def get_connection() -> psycopg.Connection:
    """Construit une connexion PostgreSQL à partir des variables locales."""

    return psycopg.connect(
        host=os.environ["POSTGRES_HOST"],
        port=os.environ["POSTGRES_HOST_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_APP_USER"],
        password=os.environ["POSTGRES_APP_PASSWORD"],
    )


def read_source_as_text(spec: SourceSpec) -> pd.DataFrame:
    """Lit un fichier Excel sans appliquer de transformation métier."""

    source_path = INPUT_DIR / spec.file_name

    if not source_path.is_file():
        raise FileNotFoundError(
            f"Fichier source introuvable : {source_path}"
        )

    dataframe = pd.read_excel(
        source_path,
        dtype=str,
        keep_default_na=False,
        na_filter=False,
    )

    actual_columns = tuple(str(column) for column in dataframe.columns)

    if actual_columns != spec.source_columns:
        raise ValueError(
            "Structure inattendue pour "
            f"{source_path.name}.\n"
            f"Colonnes attendues : {spec.source_columns}\n"
            f"Colonnes trouvées : {actual_columns}"
        )

    return dataframe


def inject_source(
    cursor: psycopg.Cursor,
    spec: SourceSpec,
    dataframe: pd.DataFrame,
) -> int:
    """Injecte une source brute dans PostgreSQL avec COPY."""

    columns = (
        "source_file",
        "source_row_number",
        *spec.target_columns,
    )

    copy_statement = (
        f"COPY {spec.raw_table} ({', '.join(columns)}) "
        "FROM STDIN"
    )

    with cursor.copy(copy_statement) as copy:
        for row_number, row in enumerate(
            dataframe.itertuples(index=False, name=None),
            start=2,
        ):
            copy.write_row(
                (
                    spec.file_name,
                    str(row_number),
                    *[
                        "" if value is None else str(value)
                        for value in row
                    ],
                )
            )

    return len(dataframe)


def main() -> None:
    """Vide puis recharge les tables raw depuis les fichiers locaux."""

    loaded_sources: list[tuple[SourceSpec, pd.DataFrame]] = []

    for spec in SOURCES:
        dataframe = read_source_as_text(spec)
        loaded_sources.append((spec, dataframe))

    with get_connection() as connection:
        with connection.transaction():
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    TRUNCATE TABLE
                        raw.hr_employees_txt,
                        raw.employee_sport_profile_txt;
                    """
                )

                for spec, dataframe in loaded_sources:
                    row_count = inject_source(cursor, spec, dataframe)

                    print(
                        f"[SUCCÈS] {spec.file_name} -> "
                        f"{spec.raw_table} : {row_count} lignes"
                    )

    print("[SUCCÈS] Injection brute terminée.")


if __name__ == "__main__":
    main()
