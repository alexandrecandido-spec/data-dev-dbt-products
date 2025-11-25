{% macro get_date_dimensions(date_field) %}
  STRUCT(
    -- DLDay: YYYY-MM-DD format
    DATE_FORMAT({{ date_field }}, 'yyyy-MM-dd') AS day,
    
    -- DLMonth: YYYY-MM format
    DATE_FORMAT({{ date_field }}, 'yyyy-MM') AS month,
    
    -- DLQuarter: YYYY-QN format
    CONCAT(
      YEAR({{ date_field }}), 
      '-Q', 
      QUARTER({{ date_field }})
    ) AS quarter,
    
    -- DLWeek: Week starting Monday (YYYY-MM-DD format)
    DATE_FORMAT(
      DATE_SUB({{ date_field }}, DAYOFWEEK({{ date_field }}) - 2),
      'yyyy-MM-dd'
    ) AS week,
    
    -- DLYear: YYYY format
    CAST(YEAR({{ date_field }}) AS STRING) AS year,
    
    -- Day of week: Monday, Tuesday, etc.
    DATE_FORMAT({{ date_field }}, 'EEEE') AS day_of_week
  )
{% endmacro %}
