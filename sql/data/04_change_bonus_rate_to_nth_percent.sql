\echo :bonus_rate

BEGIN;

DELETE FROM raw.benefit_parameters_txt
WHERE source_file = '04_change_bonus_rate_to_nth_percent.sql';

UPDATE raw.benefit_parameters_txt
SET
    valid_to = now(),
    parameter_comment = 'Taux initial de la prime sportive, clôturé avant révision'
WHERE parameter_name = 'bonus_rate'
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
    '04_change_bonus_rate_to_nth_percent.sql',
    '1',
    'bonus_rate',
    :bonus_rate,
    now(),
    '',
    'Taux révisé de la prime sportive'
);

COMMIT;
