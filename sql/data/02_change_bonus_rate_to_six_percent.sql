BEGIN;

DELETE FROM raw.benefit_parameters_txt
WHERE source_file = '02_change_bonus_rate_to_six_percent.sql';

UPDATE raw.benefit_parameters_txt
SET
    valid_to = '2026-06-20',
    parameter_comment = 'Taux initial de la prime sportive, clôturé avant révision'
WHERE parameter_name = 'bonus_rate'
  AND valid_from = '2025-06-20'
  AND (
      valid_to IS NULL
      OR BTRIM(valid_to) = ''
  );

INSERT INTO raw.benefit_parameters_txt (
    source_file,
    source_row_number,
    parameter_name,
    parameter_value,
    valid_from,
    valid_to,
    parameter_comment
)
VALUES (
    '02_change_bonus_rate_to_six_percent.sql',
    '1',
    'bonus_rate',
    '0.06',
    '2026-06-21',
    '',
    'Taux révisé de la prime sportive'
);

COMMIT;
