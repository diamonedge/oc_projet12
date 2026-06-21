with calculation_context as (

    select
        max(activity_date) as calculation_as_of_date

    from {{ ref('fct_sport_activities') }}

),

ranked_parameter_versions as (

    select
        parameters.parameter_name,
        parameters.parameter_value,

        row_number() over (
            partition by parameters.parameter_name
            order by
                parameters.valid_from desc,
                parameters.source_row_number desc
        ) as parameter_rank

    from {{ ref('config_benefit_parameters') }} as parameters

    cross join calculation_context

    where parameters.record_is_valid
      and parameters.parameter_name in (
          'bonus_rate',
          'max_commute_distance_walking_km',
          'max_commute_distance_cycling_km'
      )
      and parameters.valid_from <= calculation_context.calculation_as_of_date
      and (
          parameters.valid_to is null
          or parameters.valid_to >= calculation_context.calculation_as_of_date
      )

),

active_parameters as (

    select
        max(parameter_value) filter (
            where parameter_name = 'bonus_rate'
        ) as bonus_rate,

        max(parameter_value) filter (
            where parameter_name = 'max_commute_distance_walking_km'
        ) as max_commute_distance_walking_km,

        max(parameter_value) filter (
            where parameter_name = 'max_commute_distance_cycling_km'
        ) as max_commute_distance_cycling_km

    from ranked_parameter_versions

    where parameter_rank = 1

),

ranked_routes as (

    select
        employee_id,
        declared_commute_mode,
        google_travel_mode,
        route_distance_meters,
        route_distance_km,
        route_duration_seconds,
        requested_at,

        row_number() over (
            partition by employee_id
            order by requested_at desc, source_row_number desc
        ) as route_rank

    from {{ ref('stg_google_routes_responses') }}

    where record_is_valid

),

latest_valid_routes as (

    select
        employee_id,
        declared_commute_mode,
        google_travel_mode,
        route_distance_meters,
        route_distance_km,
        route_duration_seconds,
        requested_at

    from ranked_routes

    where route_rank = 1

),

employees as (

    select
        employee_id,
        last_name,
        first_name,
        business_unit,
        gross_salary,
        commute_mode

    from {{ ref('stg_hr_employees') }}

    where record_is_valid

),

base as (

    select
        employees.employee_id,
        employees.last_name,
        employees.first_name,
        employees.business_unit,
        employees.gross_salary,
        employees.commute_mode,

        calculation_context.calculation_as_of_date,

        active_parameters.bonus_rate,
        active_parameters.max_commute_distance_walking_km,
        active_parameters.max_commute_distance_cycling_km,

        latest_valid_routes.google_travel_mode,
        latest_valid_routes.route_distance_meters,
        latest_valid_routes.route_distance_km,
        latest_valid_routes.route_duration_seconds,
        latest_valid_routes.requested_at as route_requested_at,

        employees.commute_mode in (
            'Marche/running',
            'Vélo/Trottinette/Autres'
        ) as is_active_commute_declared,

        latest_valid_routes.employee_id is not null as has_valid_route,

        case
            when employees.commute_mode = 'Marche/running'
                then active_parameters.max_commute_distance_walking_km
            when employees.commute_mode = 'Vélo/Trottinette/Autres'
                then active_parameters.max_commute_distance_cycling_km
            else null
        end as maximum_authorized_distance_km

    from employees

    left join latest_valid_routes
        on employees.employee_id = latest_valid_routes.employee_id

    cross join calculation_context
    cross join active_parameters

),

eligibility as (

    select
        *,

        case
            when bonus_rate is null
              or max_commute_distance_walking_km is null
              or max_commute_distance_cycling_km is null
                then 'PARAMETERS_NOT_AVAILABLE'

            when not is_active_commute_declared
                then 'NOT_ACTIVE_COMMUTE_DECLARED'

            when not has_valid_route
                then 'ROUTE_INVALID_OR_MISSING'

            when route_distance_km > maximum_authorized_distance_km
                then 'DISTANCE_ABOVE_LIMIT'

            else 'ELIGIBLE'
        end as eligibility_reason

    from base

)

select
    employee_id,
    last_name,
    first_name,
    business_unit,
    gross_salary,
    commute_mode,

    calculation_as_of_date,

    bonus_rate,
    max_commute_distance_walking_km,
    max_commute_distance_cycling_km,

    google_travel_mode,
    route_distance_meters,
    route_distance_km,
    route_duration_seconds,
    round(route_duration_seconds / 60.0, 2) as route_duration_minutes,
    route_requested_at,

    is_active_commute_declared,
    has_valid_route,
    maximum_authorized_distance_km,

    eligibility_reason,
    eligibility_reason = 'ELIGIBLE' as is_commute_bonus_eligible,

    case
        when eligibility_reason = 'ELIGIBLE'
            then round(gross_salary * bonus_rate, 2)
        else 0::numeric
    end as annual_commute_bonus_gross

from eligibility
