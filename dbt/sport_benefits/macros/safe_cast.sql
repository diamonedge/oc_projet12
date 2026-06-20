{% macro clean_text(expression) -%}
    nullif(btrim({{ expression }}), '')
{%- endmacro %}


{% macro safe_cast(expression, target_type) -%}
    case
        when {{ clean_text(expression) }} is null then null
        when pg_input_is_valid(
            {{ clean_text(expression) }},
            '{{ target_type }}'
        )
        then {{ clean_text(expression) }}::{{ target_type }}
        else null
    end
{%- endmacro %}
