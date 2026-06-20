BEGIN;

TRUNCATE TABLE raw.benefit_parameters_txt;

INSERT INTO raw.benefit_parameters_txt (
    source_file,
    source_row_number,
    parameter_name,
    parameter_value,
    valid_from,
    valid_to,
    parameter_comment
)
VALUES
    (
        '01_inject_benefit_parameters.sql',
        '1',
        'bonus_rate',
        '0.05',
        '2025-06-20',
        '',
        'Taux initial de la prime sportive'
    ),
    (
        '01_inject_benefit_parameters.sql',
        '2',
        'wellbeing_activity_threshold',
        '15',
        '2025-06-20',
        '',
        'Nombre minimal d activités sur douze mois'
    ),
    (
        '01_inject_benefit_parameters.sql',
        '3',
        'wellbeing_days',
        '5',
        '2025-06-20',
        '',
        'Nombre de jours bien-être accordés'
    ),
    (
        '01_inject_benefit_parameters.sql',
        '4',
        'max_commute_distance_walking_km',
        '15',
        '2025-06-20',
        '',
        'Distance maximale marche ou course à pied'
    ),
    (
        '01_inject_benefit_parameters.sql',
        '5',
        'max_commute_distance_cycling_km',
        '25',
        '2025-06-20',
        '',
        'Distance maximale vélo, trottinette ou autre'
    );

COMMIT;
