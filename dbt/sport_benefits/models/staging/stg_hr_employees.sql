with typed as (

    select
        {{ clean_text('source_file') }} as source_file,
        {{ clean_text('source_row_number') }} as source_row_number_raw,
        {{ safe_cast('source_row_number', 'integer') }} as source_row_number,

        {{ clean_text('employee_id') }} as employee_id_raw,
        {{ safe_cast('employee_id', 'integer') }} as employee_id,

        {{ clean_text('last_name') }} as last_name,
        {{ clean_text('first_name') }} as first_name,

        {{ clean_text('birth_date') }} as birth_date_raw,
        {{ safe_cast('birth_date', 'date') }} as birth_date,

        {{ clean_text('business_unit') }} as business_unit,

        {{ clean_text('hire_date') }} as hire_date_raw,
        {{ safe_cast('hire_date', 'date') }} as hire_date,

        {{ clean_text('gross_salary') }} as gross_salary_raw,
        {{ safe_cast('gross_salary', 'numeric') }} as gross_salary,

        {{ clean_text('contract_type') }} as contract_type,

        {{ clean_text('paid_leave_days') }} as paid_leave_days_raw,
        {{ safe_cast('paid_leave_days', 'integer') }} as paid_leave_days,

        {{ clean_text('home_address') }} as home_address,
        {{ clean_text('commute_mode') }} as commute_mode

    from {{ source('raw', 'hr_employees_txt') }}

),

validated as (

    select
        *,
        (
            source_file is not null
            and source_row_number is not null
            and employee_id is not null
            and last_name is not null
            and first_name is not null
            and birth_date is not null
            and business_unit is not null
            and hire_date is not null
            and gross_salary is not null
            and gross_salary > 0
            and contract_type is not null
            and paid_leave_days is not null
            and paid_leave_days >= 0
            and home_address is not null
            and commute_mode is not null
        ) as record_is_valid

    from typed

)

select *
from validated
