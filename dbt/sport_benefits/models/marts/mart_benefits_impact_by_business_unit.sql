with employee_benefits as (

    select
        commute.calculation_as_of_date,
        commute.employee_id,
        commute.business_unit,

        commute.is_active_commute_declared,
        commute.has_valid_route,
        commute.is_commute_bonus_eligible,
        commute.annual_commute_bonus_gross,

        wellbeing.is_wellbeing_eligible,
        wellbeing.awarded_wellbeing_days

    from {{ ref('mart_commute_bonus_eligibility') }} as commute

    inner join {{ ref('mart_wellbeing_eligibility') }} as wellbeing
        on commute.employee_id = wellbeing.employee_id

),

aggregated as (

    select
        calculation_as_of_date,
        business_unit,

        count(*) as employee_count,

        count(*) filter (
            where is_active_commute_declared
        ) as active_commute_declared_employee_count,

        count(*) filter (
            where has_valid_route
        ) as employee_with_valid_route_count,

        count(*) filter (
            where is_commute_bonus_eligible
        ) as commute_bonus_eligible_employee_count,

        coalesce(
            round(sum(annual_commute_bonus_gross), 2),
            0
        ) as annual_commute_bonus_gross,

        count(*) filter (
            where is_wellbeing_eligible
        ) as wellbeing_eligible_employee_count,

        coalesce(
            sum(awarded_wellbeing_days),
            0
        ) as awarded_wellbeing_days,

        count(*) filter (
            where is_wellbeing_eligible
               or is_commute_bonus_eligible
        ) as employee_with_at_least_one_benefit_count,

        count(*) filter (
            where is_wellbeing_eligible
              and is_commute_bonus_eligible
        ) as employee_with_both_benefits_count

    from employee_benefits

    group by
        calculation_as_of_date,
        business_unit

)

select *
from aggregated
