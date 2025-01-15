{% macro get_key_value(column, key, is_array=false, value_type=none, json_path=none) %}
    {% if is_array %}
        nullif(
            element_at(
                filter({{ column }}, x -> x.key = '{{ key }}'),
                1
            ){% if value_type %}.value.{{ value_type }}{% endif %},
            ''
        ){% if value_type %}::{{ value_type }}{% endif %}
    {% else %}
        {% if json_path %}
            get_json_object(
                {{ column }}['{{ key }}'],
                '$.{{ json_path }}'
            ){% if value_type %}::{{ value_type }}{% endif %}
        {% else %}
            element_at({{ column }}, '{{ key }}'){% if value_type %}::{{ value_type }}{% endif %}
        {% endif %}
    {% endif %}
{% endmacro %}