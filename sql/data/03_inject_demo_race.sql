BEGIN;

DELETE FROM raw.sport_activities_txt
WHERE source_file = '03_inject_demo_race.sql';

INSERT INTO raw.sport_activities_txt (
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
VALUES (
    '03_inject_demo_race.sql',
    '1',
    '900000001',
    '18941',
    '2026-06-21 18:30:00',
    'Course à pied',
    '10000',
    '2026-06-21 19:20:00',
    '3000',
    'Course de démonstration après révision du taux de prime',
    'DEMO'
);

COMMIT;
