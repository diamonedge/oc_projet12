"""Publication durable des activités sportives dans Slack."""

from __future__ import annotations

import argparse
import os
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Final

import psycopg
import requests


SLACK_POST_MESSAGE_URL: Final[str] = "https://slack.com/api/chat.postMessage"
SLACK_GET_PERMALINK_URL: Final[str] = "https://slack.com/api/chat.getPermalink"
SLACK_CHANNEL_DELAY_SECONDS: Final[float] = 1.1


@dataclass(frozen=True)
class ClaimedActivity:
    """Activité revendiquée pour publication Slack."""

    activity_id: int
    employee_id: int
    activity_start_datetime: datetime
    sport_type: str
    distance_meters: float | None
    elapsed_seconds: int | None
    activity_comment: str | None
    source_system: str | None


@dataclass(frozen=True)
class SlackPostResult:
    """Résultat de l'appel Slack chat.postMessage."""

    succeeded: bool
    channel_id: str | None
    message_ts: str | None
    error_message: str | None


def get_required_environment_variable(name: str) -> str:
    """Retourne une variable d'environnement obligatoire."""

    value = os.environ.get(name, "").strip()

    if not value or value == "change_me":
        raise RuntimeError(
            f"La variable d'environnement {name} doit être configurée."
        )

    return value


def get_connection() -> psycopg.Connection:
    """Ouvre une connexion PostgreSQL avec le rôle applicatif."""

    return psycopg.connect(
        host=get_required_environment_variable("POSTGRES_HOST"),
        port=get_required_environment_variable("POSTGRES_HOST_PORT"),
        dbname=get_required_environment_variable("POSTGRES_DB"),
        user=get_required_environment_variable("POSTGRES_APP_USER"),
        password=get_required_environment_variable("POSTGRES_APP_PASSWORD"),
    )


def recover_stale_claims(stale_claim_minutes: int) -> int:
    """Place en erreur les activités bloquées en cours de publication."""

    stale_before = datetime.now(timezone.utc) - timedelta(
        minutes=stale_claim_minutes
    )

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE ops.slack_publication_queue
                SET
                    publication_status = 'ERROR',
                    last_error = 'STALE_IN_PROGRESS_CLAIM',
                    updated_at = CURRENT_TIMESTAMP
                WHERE publication_status = 'IN_PROGRESS'
                  AND claimed_at < %s;
                """,
                (stale_before,),
            )

            recovered_count = cursor.rowcount

        connection.commit()

    return recovered_count


def claim_activities(
    limit: int,
    retry_errors: bool,
) -> list[ClaimedActivity]:
    """Revendique un lot d'activités sans collision entre exécutions."""

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                WITH candidates AS (
                    SELECT activity_id
                    FROM ops.slack_publication_queue
                    WHERE publication_status = 'PENDING'
                       OR (
                           %s
                           AND publication_status = 'ERROR'
                       )
                    ORDER BY
                        activity_start_datetime,
                        activity_id
                    LIMIT %s
                    FOR UPDATE SKIP LOCKED
                )
                UPDATE ops.slack_publication_queue AS queue
                SET
                    publication_status = 'IN_PROGRESS',
                    attempt_count = queue.attempt_count + 1,
                    claimed_at = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP,
                    last_error = NULL
                FROM candidates
                WHERE queue.activity_id = candidates.activity_id
                RETURNING
                    queue.activity_id,
                    queue.employee_id,
                    queue.activity_start_datetime,
                    queue.sport_type,
                    queue.distance_meters,
                    queue.elapsed_seconds,
                    queue.activity_comment,
                    queue.source_system;
                """,
                (retry_errors, limit),
            )

            activities = [
                ClaimedActivity(
                    activity_id=activity_id,
                    employee_id=employee_id,
                    activity_start_datetime=activity_start_datetime,
                    sport_type=sport_type,
                    distance_meters=(
                        float(distance_meters)
                        if distance_meters is not None
                        else None
                    ),
                    elapsed_seconds=elapsed_seconds,
                    activity_comment=activity_comment,
                    source_system=source_system,
                )
                for (
                    activity_id,
                    employee_id,
                    activity_start_datetime,
                    sport_type,
                    distance_meters,
                    elapsed_seconds,
                    activity_comment,
                    source_system,
                ) in cursor.fetchall()
            ]

        connection.commit()

    return activities


def preview_activities(
    limit: int,
    retry_errors: bool,
) -> list[ClaimedActivity]:
    """Retourne un lot sans modifier l'état de la file."""

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    activity_id,
                    employee_id,
                    activity_start_datetime,
                    sport_type,
                    distance_meters,
                    elapsed_seconds,
                    activity_comment,
                    source_system
                FROM ops.slack_publication_queue
                WHERE publication_status = 'PENDING'
                   OR (
                       %s
                       AND publication_status = 'ERROR'
                   )
                ORDER BY
                    activity_start_datetime,
                    activity_id
                LIMIT %s;
                """,
                (retry_errors, limit),
            )

            activities = [
                ClaimedActivity(
                    activity_id=activity_id,
                    employee_id=employee_id,
                    activity_start_datetime=activity_start_datetime,
                    sport_type=sport_type,
                    distance_meters=(
                        float(distance_meters)
                        if distance_meters is not None
                        else None
                    ),
                    elapsed_seconds=elapsed_seconds,
                    activity_comment=activity_comment,
                    source_system=source_system,
                )
                for (
                    activity_id,
                    employee_id,
                    activity_start_datetime,
                    sport_type,
                    distance_meters,
                    elapsed_seconds,
                    activity_comment,
                    source_system,
                ) in cursor.fetchall()
            ]

    return activities


def format_distance(distance_meters: float | None) -> str:
    """Formate une distance pour un message Slack."""

    if distance_meters is None:
        return "non renseignée"

    return f"{distance_meters / 1000:.2f} km"


def format_duration(elapsed_seconds: int | None) -> str:
    """Formate une durée pour un message Slack."""

    if elapsed_seconds is None:
        return "non renseignée"

    minutes, seconds = divmod(elapsed_seconds, 60)
    hours, minutes = divmod(minutes, 60)

    if hours:
        return f"{hours} h {minutes:02d} min"

    return f"{minutes} min {seconds:02d} s"


def build_message(activity: ClaimedActivity) -> str:
    """Construit le contenu textuel de publication Slack."""

    activity_datetime = activity.activity_start_datetime.astimezone(
        timezone.utc
    ).strftime("%d/%m/%Y à %H:%M UTC")

    lines = [
        "Nouvelle activité sportive",
        f"Activité : {activity.sport_type}",
        f"Salarié : {activity.employee_id}",
        f"Début : {activity_datetime}",
        f"Distance : {format_distance(activity.distance_meters)}",
        f"Durée : {format_duration(activity.elapsed_seconds)}",
        f"Identifiant activité : {activity.activity_id}",
    ]

    if activity.activity_comment:
        normalized_comment = " ".join(activity.activity_comment.split())
        lines.append(f"Commentaire : {normalized_comment}")

    return "\n".join(lines)


def post_message(
    token: str,
    channel_id: str,
    message: str,
) -> SlackPostResult:
    """Publie un message dans Slack."""

    try:
        response = requests.post(
            SLACK_POST_MESSAGE_URL,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json; charset=utf-8",
            },
            json={
                "channel": channel_id,
                "text": message,
                "unfurl_links": False,
                "unfurl_media": False,
            },
            timeout=30,
        )
    except requests.RequestException as error:
        return SlackPostResult(
            succeeded=False,
            channel_id=None,
            message_ts=None,
            error_message=f"REQUEST_ERROR: {error}",
        )

    try:
        payload = response.json()
    except ValueError:
        return SlackPostResult(
            succeeded=False,
            channel_id=None,
            message_ts=None,
            error_message=(
                f"INVALID_JSON_RESPONSE: HTTP {response.status_code}"
            ),
        )

    if not payload.get("ok"):
        return SlackPostResult(
            succeeded=False,
            channel_id=None,
            message_ts=None,
            error_message=(
                f"SLACK_ERROR: {payload.get('error', 'unknown_error')}"
            ),
        )

    returned_channel_id = payload.get("channel")
    message_ts = payload.get("ts")

    if not returned_channel_id or not message_ts:
        return SlackPostResult(
            succeeded=False,
            channel_id=None,
            message_ts=None,
            error_message="SLACK_ERROR: missing_channel_or_message_ts",
        )

    return SlackPostResult(
        succeeded=True,
        channel_id=str(returned_channel_id),
        message_ts=str(message_ts),
        error_message=None,
    )


def get_permalink(
    token: str,
    channel_id: str,
    message_ts: str,
) -> tuple[str | None, str | None]:
    """Récupère le permalink d'un message Slack déjà publié."""

    try:
        response = requests.get(
            SLACK_GET_PERMALINK_URL,
            headers={
                "Authorization": f"Bearer {token}",
            },
            params={
                "channel": channel_id,
                "message_ts": message_ts,
            },
            timeout=30,
        )
    except requests.RequestException as error:
        return None, f"PERMALINK_REQUEST_ERROR: {error}"

    try:
        payload = response.json()
    except ValueError:
        return (
            None,
            f"PERMALINK_INVALID_JSON_RESPONSE: HTTP {response.status_code}",
        )

    if not payload.get("ok"):
        return (
            None,
            f"PERMALINK_SLACK_ERROR: {payload.get('error', 'unknown_error')}",
        )

    permalink = payload.get("permalink")

    if not permalink:
        return None, "PERMALINK_SLACK_ERROR: missing_permalink"

    return str(permalink), None


def mark_published(
    activity_id: int,
    channel_id: str,
    message_ts: str,
    permalink: str | None,
    permalink_error: str | None,
) -> None:
    """Enregistre une publication Slack réussie."""

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE ops.slack_publication_queue
                SET
                    publication_status = 'PUBLISHED',
                    published_at = CURRENT_TIMESTAMP,
                    slack_channel_id = %s,
                    slack_message_ts = %s,
                    slack_permalink = %s,
                    last_error = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE activity_id = %s
                  AND publication_status = 'IN_PROGRESS';
                """,
                (
                    channel_id,
                    message_ts,
                    permalink,
                    permalink_error,
                    activity_id,
                ),
            )

        connection.commit()


def mark_error(activity_id: int, error_message: str) -> None:
    """Enregistre une erreur de publication sans perdre l'activité."""

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                UPDATE ops.slack_publication_queue
                SET
                    publication_status = 'ERROR',
                    last_error = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE activity_id = %s
                  AND publication_status = 'IN_PROGRESS';
                """,
                (error_message[:2_000], activity_id),
            )

        connection.commit()


def repair_missing_permalinks(
    token: str,
    limit: int,
) -> tuple[int, int]:
    """Complète les permaliens manquants sans republier les messages."""

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    activity_id,
                    slack_channel_id,
                    slack_message_ts
                FROM ops.slack_publication_queue
                WHERE publication_status = 'PUBLISHED'
                  AND slack_permalink IS NULL
                  AND slack_channel_id IS NOT NULL
                  AND slack_message_ts IS NOT NULL
                ORDER BY published_at, activity_id
                LIMIT %s;
                """,
                (limit,),
            )

            messages = cursor.fetchall()

    repaired_count = 0
    error_count = 0

    for activity_id, channel_id, message_ts in messages:
        permalink, error_message = get_permalink(
            token=token,
            channel_id=str(channel_id),
            message_ts=str(message_ts),
        )

        with get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE ops.slack_publication_queue
                    SET
                        slack_permalink = %s,
                        last_error = %s,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE activity_id = %s
                      AND publication_status = 'PUBLISHED';
                    """,
                    (
                        permalink,
                        error_message,
                        activity_id,
                    ),
                )

            connection.commit()

        if permalink:
            repaired_count += 1
            print(
                "[SUCCÈS] "
                f"permalink réparé pour activity_id={activity_id}"
            )
        else:
            error_count += 1
            print(
                "[ERREUR] "
                f"permalink non récupéré pour activity_id={activity_id} "
                f"error={error_message}"
            )

    return repaired_count, error_count


def parse_arguments() -> argparse.Namespace:
    """Lit les paramètres d'exécution."""

    parser = argparse.ArgumentParser(
        description="Publie un lot contrôlé d'activités dans Slack."
    )

    parser.add_argument(
        "--limit",
        type=int,
        default=1,
        help="Nombre maximal d'activités à traiter.",
    )

    parser.add_argument(
        "--retry-errors",
        action="store_true",
        help="Inclut les activités précédemment en erreur.",
    )

    parser.add_argument(
        "--stale-claim-minutes",
        type=int,
        default=15,
        help="Âge maximal d'une revendication avant passage en erreur.",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Prévisualise le lot sans publier ni modifier la file.",
    )

    parser.add_argument(
        "--repair-missing-permalinks",
        action="store_true",
        help="Complète les permaliens manquants sans republier.",
    )

    return parser.parse_args()


def main() -> int:
    """Publie un lot d'activités puis met à jour la file durable."""

    arguments = parse_arguments()

    if arguments.limit <= 0:
        raise ValueError("--limit doit être strictement positif.")

    if arguments.stale_claim_minutes <= 0:
        raise ValueError(
            "--stale-claim-minutes doit être strictement positif."
        )

    if (
        arguments.dry_run
        and arguments.repair_missing_permalinks
    ):
        raise ValueError(
            "--dry-run et --repair-missing-permalinks "
            "ne peuvent pas être combinés."
        )

    if arguments.dry_run:
        activities = preview_activities(
            limit=arguments.limit,
            retry_errors=arguments.retry_errors,
        )

        for activity in activities:
            print(
                "[DRY-RUN] "
                f"activity_id={activity.activity_id} "
                f"employee_id={activity.employee_id} "
                f"sport_type={activity.sport_type}"
            )

        print(f"[INFO] Activités prévisualisées : {len(activities)}.")
        return 0

    token = get_required_environment_variable("SLACK_BOT_TOKEN")

    if arguments.repair_missing_permalinks:
        repaired_count, error_count = repair_missing_permalinks(
            token=token,
            limit=arguments.limit,
        )

        print(
            "[INFO] Permaliens réparés : "
            f"{repaired_count}; erreurs : {error_count}."
        )
        return 1 if error_count else 0

    channel_id = get_required_environment_variable("SLACK_CHANNEL_ID")

    recovered_count = recover_stale_claims(
        stale_claim_minutes=arguments.stale_claim_minutes
    )

    if recovered_count:
        print(
            "[INFO] Revendications expirées placées en erreur : "
            f"{recovered_count}."
        )

    activities = claim_activities(
        limit=arguments.limit,
        retry_errors=arguments.retry_errors,
    )

    if not activities:
        print("[INFO] Aucune activité à publier.")
        return 0

    error_count = 0

    for index, activity in enumerate(activities):
        post_result = post_message(
            token=token,
            channel_id=channel_id,
            message=build_message(activity),
        )

        if not post_result.succeeded:
            mark_error(
                activity_id=activity.activity_id,
                error_message=post_result.error_message or "UNKNOWN_ERROR",
            )
            error_count += 1

            print(
                "[ERREUR] "
                f"activity_id={activity.activity_id} "
                f"error={post_result.error_message}"
            )
        else:
            permalink, permalink_error = get_permalink(
                token=token,
                channel_id=post_result.channel_id or channel_id,
                message_ts=post_result.message_ts or "",
            )

            mark_published(
                activity_id=activity.activity_id,
                channel_id=post_result.channel_id or channel_id,
                message_ts=post_result.message_ts or "",
                permalink=permalink,
                permalink_error=permalink_error,
            )

            print(
                "[SUCCÈS] "
                f"activity_id={activity.activity_id} "
                f"slack_message_ts={post_result.message_ts}"
            )

        if index < len(activities) - 1:
            time.sleep(SLACK_CHANNEL_DELAY_SECONDS)

    if error_count:
        print(f"[ERREUR] Publications en échec : {error_count}.")
        return 1

    print(f"[SUCCÈS] Publications Slack terminées : {len(activities)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
