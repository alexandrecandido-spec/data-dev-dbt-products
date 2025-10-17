{% macro check_table_exists(table_name) %}
    {% set query %}
        SELECT COUNT(*) as table_count
        FROM information_schema.tables 
        WHERE table_name = '{{ table_name }}'
    {% endset %}
    
    {% set results = run_query(query) %}
    {% if execute %}
        {% set table_count = results.columns[0].values()[0] %}
        {% if table_count > 0 %}
            {{ return(true) }}
        {% else %}
            {{ return(false) }}
        {% endif %}
    {% endif %}
{% endmacro %}