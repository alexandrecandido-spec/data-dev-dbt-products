{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    unique_key           = 'unique_session',
    on_schema_change     = 'fail',
    tags                 = ['daily-6am', 'marketing']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['unique_session', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

main_source AS (
    SELECT
        unique_session,
        start_session_time,
        end_session_time,
CASE
    WHEN end_session_time IS NOT NULL 
         AND start_session_time IS NOT NULL
         AND end_session_time >= start_session_time
    THEN ROUND((end_session_time - start_session_time) / 60000000.0, 2)
    ELSE NULL
END AS session_duration_minutes,

CASE
    WHEN engage IS NOT NULL THEN engage
    WHEN end_session_time IS NOT NULL 
         AND start_session_time IS NOT NULL
         AND end_session_time >= start_session_time
         AND ROUND((end_session_time - start_session_time) / 60000000.0, 2) > 0
    THEN 1 
    ELSE 0
END AS engage,

        start_session_date,
        CAST(date_format(start_session_date, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM {{ source('stg_ga4','session_info') }}
    WHERE unique_session IS NOT NULL
      AND start_session_date >= DATE '2024-01-01'
),

final AS (
    SELECT
        main_source.*,
        COALESCE(e.sys_audit_created_on, current_timestamp)     AS sys_audit_created_on,
        COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
        current_timestamp                                        AS sys_audit_updated_on,
        'data-dev-dbt-products'                                  AS sys_audit_updated_by
    FROM main_source
    LEFT JOIN existing_data e
      ON main_source.unique_session = e.unique_session
)

SELECT *
FROM final
{% if is_incremental() %}
WHERE start_session_date > (
  SELECT COALESCE(MAX(start_session_date), DATE '1900-01-01')
  FROM {{ this }}
)
{% endif %}




