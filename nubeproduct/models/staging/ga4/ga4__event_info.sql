{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    unique_key           = ['unique_session','event_name','event_date','event_device'],
    on_schema_change     = 'fail',
    tags                 = ['daily-6am', 'marketing']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['unique_session', 'event_name', 'event_date', 'event_device', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

main_source AS (
    SELECT
        unique_session,
        event_name,
        event_date,
        event_device,
        CASE WHEN instr(lower(event_name), 'login') > 0 THEN 'login' ELSE 'other' END AS event_type,
        CAST(date_format(event_date, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM {{ source('stg_ga4','event_info') }}
    WHERE unique_session IS NOT NULL
      AND event_date >= DATE '2024-01-01'
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
     AND main_source.event_name     = e.event_name
     AND main_source.event_date     = e.event_date
     AND main_source.event_device   = e.event_device
)

SELECT *
FROM final
{% if is_incremental() %}
WHERE event_date > (
  SELECT COALESCE(MAX(event_date), DATE '1900-01-01') FROM {{ this }}
)
{% endif %}

