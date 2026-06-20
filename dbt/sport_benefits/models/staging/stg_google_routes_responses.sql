with typed as (
select
    {{ clean_text('source_file') }} as source_file,

    {{ clean_text('source_row_number') }} as source_row_number_raw,
    {{ safe_cast('source_row_number', 'integer') }} as source_row_number,

    {{ clean_text('request_key') }} as request_key,

    {{ clean_text('employee_id') }} as employee_id_raw,
    {{ safe_cast('employee_id', 'integer') }} as employee_id,

    {{ clean_text('home_address') }} as home_address,
    {{ clean_text('office_address') }} as office_address,
    {{ clean_text('declared_commute_mode') }} as declared_commute_mode,
    {{ clean_text('google_travel_mode') }} as google_travel_mode,

    {{ clean_text('request_payload_json') }} as request_payload_json_raw,

    {{ clean_text('response_http_status') }} as response_http_status_raw,
    {{ safe_cast('response_http_status', 'integer') }}
        as response_http_status,

    {{ clean_text('response_payload_json') }}
        as response_payload_json_raw,
    {{ safe_cast('response_payload_json', 'jsonb') }}
        as response_payload_json,

    {{ clean_text('requested_at') }} as requested_at_raw,
    {{ safe_cast('requested_at', 'timestamp with time zone') }}
        as requested_at

from {{ source('raw', 'google_routes_responses_txt') }}
),

parsed as (
select
    *,

    {{ safe_cast(
        "response_payload_json #>> '{routes,0,distanceMeters}'",
        'integer'
    ) }} as route_distance_meters,

    {{ safe_cast(
        "regexp_replace(
            response_payload_json #>> '{routes,0,duration}',
            's$',
            ''
        )",
        'integer'
    ) }} as route_duration_seconds

from typed
),

validated as (
select
    *,

    route_distance_meters / 1000.0 as route_distance_km,

    case
        when source_file is not null
         and source_row_number is not null
         and request_key is not null
         and employee_id is not null
         and employee_id > 0
         and home_address is not null
         and office_address is not null
         and declared_commute_mode in (
             'Marche/running',
             'Vélo/Trottinette/Autres'
         )
         and google_travel_mode in ('WALK', 'BICYCLE')
         and (
             declared_commute_mode = 'Marche/running'
             and google_travel_mode = 'WALK'
             or declared_commute_mode = 'Vélo/Trottinette/Autres'
             and google_travel_mode = 'BICYCLE'
         )
         and response_http_status = 200
         and response_payload_json is not null
         and route_distance_meters is not null
         and route_distance_meters > 0
         and route_duration_seconds is not null
         and route_duration_seconds >= 0
         and requested_at is not null
        then true
        else false
    end as record_is_valid

from parsed
)

select *
from validated
