{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    unique_key           = 'unique_session',
    on_schema_change     = 'fail',
    tags                 = ['daily-5am', 'marketing']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['unique_session', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

main_source AS (
    SELECT
        unique_session,
        trial_timestamp,
        payment_timestamp,
        trial_date,
        payment_date,

        CAST(
            date_format(
                COALESCE(LEAST(trial_date, payment_date), trial_date, payment_date),
                'yyyyMMdd'
            ) AS INT
        ) AS year_month_day_code
    FROM {{ source('stg_ga4','tp_info') }}
    WHERE unique_session IS NOT NULL
      AND (trial_date >= DATE '2024-01-01' OR payment_date >= DATE '2024-01-01')
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
WHERE COALESCE(trial_date, payment_date) > (
  SELECT COALESCE(MAX(COALESCE(trial_date, payment_date)), DATE '1900-01-01')
  FROM {{ this }}
)
{% endif %}




    