 {{config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'unique_session',
    partition_by = ['trial_year_month_code', 'payment_year_month_code'],
    tags = ['daily-5am'],
    on_schema_change = 'fail'
) }}

SELECT
    unique_session,
    trial_timestamp,
    payment_timestamp,
    trial_date,
    payment_date,
    date_format(trial_date,   'yyyyMM') AS trial_year_month_code,
    date_format(payment_date, 'yyyyMM') AS payment_year_month_code,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_ga4', 'tp_info') }}
WHERE 1=1
  AND unique_session IS NOT NULL
  {% if not is_incremental() %}
    AND (trial_date >= DATE '2024-01-01' OR payment_date >= DATE '2024-01-01')
  {% endif %}
  {% if is_incremental() %}
    AND sys_audit_updated_on > (
      SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
      FROM {{ this }}
    )
  {% endif %}


    