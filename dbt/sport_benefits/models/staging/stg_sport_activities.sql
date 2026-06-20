with typed as (

    select
        {{ clean_text('source_file') }} as source_file,

        {{ clean_text('source_row_number') }} as source_row_number_raw,
        {{ safe_cast('source_row_number', 'integer') }} as source_row_number,

        {{ clean_text('activity_id') }} as activity_id_raw,
        {{ safe_cast('activity_id', 'integer') }} as activity_id,

        {{ clean_text('employee_id') }} as employee_id_raw,
        {{ safe_cast('employee_id', 'integer') }} as employee_id,

        {{ clean_text('activity_start_datetime') }}
            as activity_start_datetime_raw,
        {{ safe_cast('activity_start_datetime', 'timestamp') }}
            as activity_start_datetime,

        {{ clean_text('sport_type') }} as sport_type_raw,

        case
            when {{ clean_text('sport_type') }} is null then null
            when lower({{ clean_text('sport_type') }}) = 'runing'
                then 'Course à pied'
            else {{ clean_text('sport_type') }}
        end as sport_type,

        {{ clean_text('distance_meters') }} as distance_meters_raw,
        {{ safe_cast('distance_meters', 'numeric') }} as distance_meters,

        {{ clean_text('activity_end_datetime') }}
            as activity_end_datetime_raw,
        {{ safe_cast('activity_end_datetime', 'timestamp') }}
            as activity_end_datetime,

        {{ clean_text('elapsed_seconds') }} as elapsed_seconds_raw,
        {{ safe_cast('elapsed_seconds', 'integer') }} as elapsed_seconds,

        {{ clean_text('activity_comment') }} as activity_comment,
        {{ clean_text('source_system') }} as source_system

    from {{ source('raw', 'sport_activities_txt') }}

),

validated as (

    select
        *,

        (
            source_file is not null
            and source_row_number is not null
        ) as has_valid_source_metadata,

        activity_id is not null as has_valid_activity_id,
        employee_id is not null as has_valid_employee_id,

        (
            activity_start_datetime is not null
            and activity_end_datetime is not null
            and activity_end_datetime > activity_start_datetime
        ) as has_valid_time_range,

        sport_type is not null as has_valid_sport_type,

        (
            elapsed_seconds is not null
            and elapsed_seconds > 0
        ) as has_valid_elapsed_seconds,

        (
            distance_meters_raw is null
            or (
                distance_meters is not null
                and distance_meters >= 0
            )
        ) as has_valid_distance,

        (
            source_file is not null
            and source_row_number is not null
            and activity_id is not null
            and employee_id is not null
            and activity_start_datetime is not null
            and activity_end_datetime is not null
            and activity_end_datetime > activity_start_datetime
            and sport_type is not null
            and elapsed_seconds is not null
            and elapsed_seconds > 0
            and (
                distance_meters_raw is null
                or (
                    distance_meters is not null
                    and distance_meters >= 0
                )
            )
        ) as record_is_valid

    from typed

)

select *
from validated
