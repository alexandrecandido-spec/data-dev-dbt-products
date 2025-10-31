{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  partition_by=['year_month_day_code'],
  unique_key=['unique_session','trial_timestamp','payment_timestamp'],
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
    'unique_session','trial_timestamp','payment_timestamp',
    'sys_audit_created_on','sys_audit_created_by'
  ]) }}
)

SELECT
    t.unique_session,
    t.trial_timestamp,           -- puede ser NULL
    t.payment_timestamp,         -- puede ser NULL
    t.trial_date,                -- DATE o NULL
    t.payment_date,              -- DATE o NULL
    COALESCE(t.trial_date, t.payment_date) AS event_date,
    CAST(date_format(COALESCE(t.trial_date, t.payment_date), 'yyyyMMdd') AS INT) AS year_month_day_code,

    COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp                                          AS sys_audit_updated_on,
    'data-dev-dbt-products'                                    AS sys_audit_updated_by

FROM {{ ref('marketing_tp_info') }} t
CROSS JOIN baseline b
LEFT JOIN existing_data e
  ON  t.unique_session    = e.unique_session
  AND t.trial_timestamp   = e.trial_timestamp
  AND t.payment_timestamp = e.payment_timestamp

WHERE t.unique_session IS NOT NULL
  AND (t.trial_timestamp IS NOT NULL OR t.payment_timestamp IS NOT NULL)
  AND COALESCE(t.trial_date, t.payment_date) >= DATE '2024-01-01'

  {% if is_incremental() %}
  AND (
        COALESCE(t.trial_date, t.payment_date) >= date_sub(date(b.last_upd), 5)
     OR t.sys_audit_updated_on >= b.last_upd - INTERVAL 5 DAY
      )
  {% endif %}






    