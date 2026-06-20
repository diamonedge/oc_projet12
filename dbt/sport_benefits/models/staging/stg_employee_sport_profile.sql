with typed as (

    select
        {{ clean_text('source_file') }} as source_file,
        {{ clean_text('source_row_number') }} as source_row_number_raw,
        {{ safe_cast('source_row_number', 'integer') }} as source_row_number,

        {{ clean_text('employee_id') }} as employee_id_raw,
        {{ safe_cast('employee_id', 'integer') }} as employee_id,

        {{ clean_text('declared_sport') }} as declared_sport_raw,

        case
            when {{ clean_text('declared_sport') }} is null then null
            when lower({{ clean_text('declared_sport') }}) = 'runing'
                then 'Course à pied'
            else {{ clean_text('declared_sport') }}
        end as sport_type

    from {{ source('raw', 'employee_sport_profile_txt') }}

),

validated as (

    select
        *,
        sport_type is not null as has_declared_sport,

        (
            source_file is not null
            and source_row_number is not null
            and employee_id is not null
        ) as record_is_valid

    from typed

)

select *
from validated
