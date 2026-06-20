with typed as (

    select
        {{ clean_text('source_file') }} as source_file,

        {{ clean_text('source_row_number') }} as source_row_number_raw,
        {{ safe_cast('source_row_number', 'integer') }} as source_row_number,

        {{ clean_text('parameter_name') }} as parameter_name,

        {{ clean_text('parameter_value') }} as parameter_value_raw,
        {{ safe_cast('parameter_value', 'numeric') }} as parameter_value,

        {{ clean_text('valid_from') }} as valid_from_raw,
        {{ safe_cast('valid_from', 'date') }} as valid_from,

        {{ clean_text('valid_to') }} as valid_to_raw,
        {{ safe_cast('valid_to', 'date') }} as valid_to,

        {{ clean_text('parameter_comment') }} as parameter_comment

    from {{ source('raw', 'benefit_parameters_txt') }}

),

validated as (

    select
        *,

        (
            parameter_name in (
                'bonus_rate',
                'wellbeing_activity_threshold',
                'wellbeing_days',
                'max_commute_distance_walking_km',
                'max_commute_distance_cycling_km'
            )
            and parameter_value is not null
            and parameter_value >= 0
            and valid_from is not null
            and (
                valid_to is null
                or valid_to >= valid_from
            )
        ) as record_is_valid

    from typed

)

select *
from validated
