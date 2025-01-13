{% macro get_property_value(col_name, key_name, value_type) %}
    nullif(
        element_at(
            filter({{ col_name }}, x -> x.key = '{{ key_name }}'),
            1
        ).value.{{ value_type }},
        ''
    )
{% endmacro %}