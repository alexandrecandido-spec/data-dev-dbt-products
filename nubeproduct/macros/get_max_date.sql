-- This macro retrieves the MAX date from a given table (relation), adds a specified time delta 
-- (in days, weeks, or months), and returns a filter clause  
-- return example: BETWEEN DATE('2024-01-01') AND DATE('2024-01-08')


{% macro get_max_date(relation=this, date_field='base_date', period_value=1, period_unit='day') %}

    {% set query %}
        SELECT MAX(DATE({{ date_field }})) AS max_date
        FROM {{ relation }}
    {% endset %}

    {% set result = run_query(query) %}
    {% set max_date = result.columns[0].values()[0] %}

    {% if not max_date %}
        {% set max_date = '1900-01-01' %}
    {% endif %}

    {% if max_date is string %}
        {% set base = modules.datetime.datetime.strptime(max_date, '%Y-%m-%d') %}
    {% else %}
        {% set base = modules.datetime.datetime.combine(max_date, modules.datetime.datetime.min.time()) %}
    {% endif %}

    {% if period_unit == 'day' %}
        {% set end = base + modules.datetime.timedelta(days=period_value) %}
    {% elif period_unit == 'week' %}
        {% set end = base + modules.datetime.timedelta(weeks=period_value) %}
    {% elif period_unit == 'month' %}
        {% set end = base + modules.datetime.timedelta(days=30 * period_value) %}
    {% else %}
        {% do exceptions.raise_compiler_error("Invalid period_unit: " ~ period_unit) %}
    {% endif %}

    {% set filter_clause = "BETWEEN DATE('" ~ base.date() ~ "') AND DATE('" ~ end.date() ~ "')" %}
    {% do log("get_max_date → " ~ filter_clause, info=True) %}

    {{ return(filter_clause) }}

{% endmacro %}