with active_parameters as (

    select
        max(parameter_value) filter (
            where parameter_name = 'wellbeing_activity_threshold'
        ) as wellbeing_activity_threshold,

        max(parameter_value) filter (
            where parameter_name = 'wellbeing_days'
        ) as wellbeing_days

    from {{ ref('config_benefit_parameters') }}

    where record_is_valid
      and valid_from <= current_date
      and (
          valid_to is null
          or valid_to >= current_date
      )

),

employee_activity_counts as (

    select
        employee_id,
        count(*) as activity_count_last_12_months,
        min(activity_date) as first_activity_date,
        max(activity_date) as last_activity_date

    from {{ ref('fct_sport_activities') }}

    where activity_date >= current_date - interval '12 months'
      and activity_date <= current_date

    group by employee_id

),

employees as (

    select
        hr.employee_id,
        hr.last_name,
        hr.first_name,
        hr.business_unit,
        coalesce(sport.has_declared_sport, false) as has_declared_sport

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
