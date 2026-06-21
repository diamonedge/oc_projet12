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
          'wellbeing_activity_threshold',
          'wellbeing_days'
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
            where parameter_name = 'wellbeing_activity_threshold'
        ) as wellbeing_activity_threshold,

        max(parameter_value) filter (
            where parameter_name = 'wellbeing_days'
        ) as wellbeing_days

    from ranked_parameter_versions

    where parameter_rank = 1

),

employee_activity_counts as (

    select
        activities.employee_id,
        count(*) as activity_count_last_12_months,
        min(activities.activity_date) as first_activity_date,
        max(activities.activity_date) as last_activity_date

    from {{ ref('fct_sport_activities') }} as activities

    cross join calculation_context

    where activities.activity_date >= (
        calculation_context.calculation_as_of_date - interval '12 months'
    )
      and activities.activity_date <= calculation_context.calculation_as_of_date

    group by activities.employee_id

),

employees as (

    select
        hr.employee_id,
        hr.last_name,
        hr.first_name,
        hr.business_unit,

        coalesce(
            sport.has_declared_sport,
            false
        ) as has_declared_sport

    from {{ ref('stg_hr_employees') }} as hr

    left join {{ ref('stg_employee_sport_profile') }} as sport
        on hr.employee_id = sport.employee_id

    where hr.record_is_valid

)

select
    employees.employee_id,
    employees.last_name,
    employees.first_name,
    employees.business_unit,
    employees.has_declared_sport,

    coalesce(
        employee_activity_counts.activity_count_last_12_months,
        0
    ) as activity_count_last_12_months,

    calculation_context.calculation_as_of_date,

    active_parameters.wellbeing_activity_threshold,
    active_parameters.wellbeing_days,

    (
        coalesce(
            employee_activity_counts.activity_count_last_12_months,
            0
        ) >= active_parameters.wellbeing_activity_threshold
    ) as is_wellbeing_eligible,

    case
        when coalesce(
            employee_activity_counts.activity_count_last_12_months,
            0
        ) >= active_parameters.wellbeing_activity_threshold
        then active_parameters.wellbeing_days
        else 0
    end as awarded_wellbeing_days,

    employee_activity_counts.first_activity_date,
    employee_activity_counts.last_activity_date

from employees

left join employee_activity_counts
    on employees.employee_id = employee_activity_counts.employee_id

cross join active_parameters
cross join calculation_context
