{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  partition_by=['year_month_day_code'],
  unique_key=['unique_session','event_name','event_timestamp','event_device'],
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
  {{ get_existing_data(this, [
    'unique_session','event_name','event_timestamp','event_device',
    'sys_audit_created_on','sys_audit_created_by'
  ]) }}
)

SELECT 
    src.unique_session,
    src.event_name,
    src.event_timestamp,
    src.event_date,
    src.event_device,
    CASE WHEN instr(lower(src.event_name),'login') > 0 THEN 'login' ELSE 'other' END AS event_type,
    CAST(date_format(src.event_date,'yyyyMMdd') AS INT) AS year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp                                          AS sys_audit_updated_on,
    'data-dev-dbt-products'                                    AS sys_audit_updated_by
FROM {{ ref('marketing_event_info') }} src, baseline b
LEFT JOIN existing_data e
  ON  src.unique_session  = e.unique_session
  AND src.event_name      = e.event_name
  AND src.event_timestamp = e.event_timestamp
  AND src.event_device    = e.event_device
WHERE src.unique_session  IS NOT NULL
  AND src.event_timestamp IS NOT NULL
  AND src.event_date     >= DATE '2024-01-01'
  {% if is_incremental() %}
  AND (
        src.event_date >= date_sub(date(b.last_upd), 5)
     OR src.sys_audit_updated_on >= b.last_upd - INTERVAL 5 DAY
      )
  {% endif %}



