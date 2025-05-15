{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'unique_session',
    partition_by = ['year_month_day_code'],
    tags = ['ga4', 'marketing', 'daily'],
    on_schema_change = 'fail'
) }}

SELECT
    unique_session,
    event_name,
    event_date,
    CAST(to_char(event_date, 'yyyyMMdd') AS STRING) AS year_month_day_code,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_ga4', 'event_info') }}
WHERE 1=1
AND unique_session IS NOT NULL
  {% if not is_incremental() %}
    AND event_date >= DATE '2024-01-01'
  {% endif %}

  {% if is_incremental() %}
    AND sys_audit_updated_on > (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }})
  {% endif %}
