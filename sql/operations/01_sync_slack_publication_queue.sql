BEGIN;

MERGE INTO ops.slack_publication_queue AS queue

USING (
    SELECT
        activity_id::bigint AS activity_id,
        employee_id,
        activity_start_datetime,
        sport_type,
        distance_meters,
        elapsed_seconds,
        activity_comment,
        source_system
    FROM marts.fct_sport_activities
) AS activities

ON queue.activity_id = activities.activity_id

WHEN NOT MATCHED THEN
    INSERT (
        activity_id,
        employee_id,
        activity_start_datetime,
        sport_type,
        distance_meters,
        elapsed_seconds,
        activity_comment,
        source_system
    )
    VALUES (
        activities.activity_id,
        activities.employee_id,
        activities.activity_start_datetime,
        activities.sport_type,
        activities.distance_meters,
        activities.elapsed_seconds,
        activities.activity_comment,
        activities.source_system
    );

COMMIT;
