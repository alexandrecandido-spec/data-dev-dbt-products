{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  partition_by=['year_month_day_code'],
  unique_key='unique_session',
  on_schema_change='fail',
  tags=['daily-6am','marketing']
) }}

WITH baseline AS (
  {% if is_incremental() %}
  SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') AS last_upd
  FROM {{ this }}
  {% else %}
  SELECT TIMESTAMP '1900-01-01' AS last_upd
  {% endif %}
),
existing_data AS (
  {{ get_existing_data(this, ['unique_session','sys_audit_created_on','sys_audit_created_by']) }}
)

SELECT
  s.unique_session,
  s.start_session_time,
  s.end_session_time,

  CASE
    WHEN s.end_session_time IS NOT NULL
         AND s.start_session_time IS NOT NULL
         AND s.end_session_time >= s.start_session_time
    THEN ROUND((s.end_session_time - s.start_session_time) / 60000000.0, 2)
    ELSE NULL
  END AS session_duration_minutes,

  CASE
    WHEN s.engage IS NOT NULL THEN s.engage
    WHEN s.end_session_time IS NOT NULL
         AND s.start_session_time IS NOT NULL
         AND s.end_session_time >= s.start_session_time
         AND ROUND((s.end_session_time - s.start_session_time) / 60000000.0, 2) > 0
    THEN 1 ELSE 0
  END AS engage,

  s.start_session_date,
  CAST(date_format(s.start_session_date, 'yyyyMMdd') AS INT) AS year_month_day_code,

  COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp                                          AS sys_audit_updated_on,
  'data-dev-dbt-products'                                    AS sys_audit_updated_by

FROM {{ ref('marketing_session_info') }} s
CROSS JOIN baseline b
LEFT JOIN existing_data e ON s.unique_session = e.unique_session
WHERE s.unique_session IS NOT NULL
  AND s.start_session_date >= DATE '2024-01-01'
  {% if is_incremental() %}
  AND (
        s.start_session_date >= date_sub(date(b.last_upd), 5)
     OR s.sys_audit_updated_on >= b.last_upd - INTERVAL 5 DAY
      )
  {% endif %}






