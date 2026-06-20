with valid_activities as (

    select
        activity_id,
        employee_id,
        activity_start_datetime,
        activity_end_datetime,
        sport_type,
        distance_meters,
        elapsed_seconds,
        activity_comment,
        source_system,
        source_file,
        source_row_number

    from {{ ref('stg_sport_activities') }}

    where record_is_valid

),

enriched as (

    select
        activity_id,
        employee_id,
        activity_start_datetime,
        activity_end_datetime,
        activity_start_datetime::date as activity_date,
        date_trunc(
            'month',
            activity_start_datetime
        )::date as activity_month,
        sport_type,
        distance_meters,
        elapsed_seconds,
        round(elapsed_seconds / 60.0, 2) as elapsed_minutes,
        activity_comment,
        source_system,
        source_file,
        source_row_number

    from valid_activities

)

select *
from enriched
