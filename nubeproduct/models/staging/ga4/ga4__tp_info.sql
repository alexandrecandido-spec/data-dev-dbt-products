{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    unique_key           = ['unique_session','trial_timestamp','payment_timestamp'],
    on_schema_change     = 'fail',
    tags                 = ['daily-6am', 'marketing']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, [
    'unique_session','trial_timestamp','payment_timestamp',
    'sys_audit_created_on','sys_audit_created_by'
  ]) }}
),

src AS (
  SELECT
      unique_session,
      trial_timestamp,          
      payment_timestamp,        
      trial_date,               
      payment_date,            

      COALESCE(trial_date, payment_date) AS event_date,

      CAST(date_format(COALESCE(trial_date, payment_date), 'yyyyMMdd') AS INT) AS year_month_day_code,

      sys_audit_updated_on
  FROM {{ source('stg_ga4','tp_info') }}
  WHERE unique_session IS NOT NULL
    AND (trial_timestamp IS NOT NULL OR payment_timestamp IS NOT NULL)
    AND COALESCE(trial_date, payment_date) >= DATE '2024-01-01'
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
    f.trial_timestamp,
    f.payment_timestamp,
    f.trial_date,
    f.payment_date,
    f.event_date,             
    f.year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp                                          AS sys_audit_updated_on,
    'data-dev-dbt-products'                                    AS sys_audit_updated_by
FROM filtered f
LEFT JOIN existing_data e
  ON  f.unique_session    <=> e.unique_session
  AND f.trial_timestamp   <=> e.trial_timestamp
  AND f.payment_timestamp <=> e.payment_timestamp




    