{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    unique_key           = ['unique_session','event_name','event_date','event_device'],
    on_schema_change     = 'sync_all_columns',
    tags                 = ['daily-5am']
) }}

WITH base AS (
    SELECT
        unique_session,
        event_name,
        event_date,
        event_device,
        CASE WHEN instr(lower(event_name),'login')>0 THEN 'login' ELSE 'other' END AS event_type,
        CAST(date_format(event_date,'yyyyMMdd') AS int)         AS year_month_day_code,
        current_timestamp()                                      AS sys_audit_updated_on
    FROM {{ source('stg_ga4','event_info') }}
    WHERE unique_session IS NOT NULL
      AND event_date >= DATE '2024-01-01'             
)

SELECT *
FROM   base
WHERE
    {% if is_incremental() %}
        year_month_day_code >= CAST(date_format(date_sub(current_date(),3),'yyyyMMdd') AS int)
        AND sys_audit_updated_on >= (
              SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
              FROM {{ this }}
            )
    {% endif %}
