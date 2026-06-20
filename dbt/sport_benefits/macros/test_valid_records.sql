{% test valid_records(model) %}

    select *
    from {{ model }}
    where coalesce(record_is_valid, false) is not true

{% endtest %}
