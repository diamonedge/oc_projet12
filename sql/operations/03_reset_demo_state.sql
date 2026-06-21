BEGIN;

TRUNCATE TABLE ops.slack_publication_queue;

TRUNCATE TABLE raw.google_routes_responses_txt;

TRUNCATE TABLE raw.sport_activities_txt;

TRUNCATE TABLE raw.benefit_parameters_txt;

TRUNCATE TABLE raw.employee_sport_profile_txt;

TRUNCATE TABLE raw.hr_employees_txt;

COMMIT;
