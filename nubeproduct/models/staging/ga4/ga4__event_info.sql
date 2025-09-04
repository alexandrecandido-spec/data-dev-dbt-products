{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    partition_by=['year_month_day_code'],
    unique_key=['unique_session','event_name','event_timestamp','event_device'],
    on_schema_change='fail',
    tags=['daily-6am','marketing']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, [
    'unique_session','event_name','event_timestamp','event_device',
    'sys_audit_created_on','sys_audit_created_by'
  ]) }}
),

src AS (
  SELECT
      unique_session,                
      event_name,
      event_timestamp,              
      event_date,
      event_device,
CASE WHEN instr(lower(event_name), 'login') > 0 THEN 'login' ELSE 'other' END AS event_type,
      CAST(date_format(event_date, 'yyyyMMdd') AS INT) AS year_month_day_code,
      sys_audit_updated_on
  FROM {{ source('stg_ga4','event_info') }}
  WHERE unique_session IS NOT NULL            
    AND event_timestamp IS NOT NULL           
    AND event_date >= DATE '2024-01-01'
    AND year_month_code >= 202401
),

filtered AS (
  SELECT * FROM src
  {% if is_incremental() %}
  WHERE sys_audit_updated_on >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01 00:00:00') FROM {{ this }}
  ) - INTERVAL 5 MINUTES
  {% endif %}
)

SELECT 
    f.unique_session,
    f.event_name,
    f.event_timestamp,
    f.event_date,
    f.event_device,
    f.event_type,
    f.year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp                                          AS sys_audit_updated_on,
    'data-dev-dbt-products'                                    AS sys_audit_updated_by
FROM filtered f
LEFT JOIN existing_data e
  ON  f.unique_session    <=> e.unique_session
  AND f.event_name        <=> e.event_name
  AND f.event_timestamp   <=> e.event_timestamp
  AND f.event_device      <=> e.event_device
