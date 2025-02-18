{% macro get_existing_data(table_name, columns) %}
    {% if is_incremental() %}
        SELECT {{ columns | join(', ') }}
        FROM {{ this }}
    {% else %}
        SELECT 
            {% for col in columns %}
                NULL AS {{ col }}{% if not loop.last %}, {% endif %}
            {% endfor %}
        WHERE FALSE
    {% endif %}
{% endmacro %}
