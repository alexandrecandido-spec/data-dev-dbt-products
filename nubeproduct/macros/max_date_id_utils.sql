-- Adds N time units (default: 4 months) to the max date field found in the table.
-- period_unit = 'day' | 'week' | 'month'

{% macro get_max_date_range(relation=this, date_field='event_date', period_value=4, period_unit='month') %}

    -- Defensive validation of period_unit
    {% if period_unit not in ['month', 'week', 'day'] %}
        {% do exceptions.raise_compiler_error("Invalid period_unit: " ~ period_unit ~ ". Use 'month', 'week', or 'day'.") %}
    {% endif %}

    max_date AS (
        SELECT 
            COALESCE(MAX(DATE({{ date_field }})), DATE('1900-01-01')) AS max_date
        FROM 
            {{ relation }}
    )

    , max_date_add AS (
        SELECT 
            max_date
            , CASE 
                WHEN '{{ period_unit }}' = 'month' THEN ADD_MONTHS(max_date, {{ period_value }})
                WHEN '{{ period_unit }}' = 'day' THEN DATE_ADD(max_date, {{ period_value }})
                WHEN '{{ period_unit }}' = 'week' THEN DATE_ADD(max_date, {{ period_value }} * 7)
                ELSE max_date
              END AS max_date_range
        FROM 
            max_date
    )

{% endmacro %}