{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    unique_key           = 'unique_session',
    on_schema_change     = 'sync_all_columns',
    tags                 = ['daily-5am']
) }}

WITH base AS (
    SELECT
        unique_session,
        start_session_time,                   
        end_session_time,

        CASE
            WHEN end_session_time IS NOT NULL AND start_session_time IS NOT NULL
            THEN (end_session_time - start_session_time) / 60000
            ELSE NULL
        END                                                      AS session_duration_minutes,

        CASE
            WHEN engage IS NOT NULL THEN engage
            WHEN end_session_time IS NOT NULL AND start_session_time IS NOT NULL
                 AND (end_session_time - start_session_time) / 60000 >= 1
            THEN 1 ELSE 0
        END                                                      AS engage,

        start_session_date,

        CAST(date_format(start_session_date,'yyyyMMdd') AS int)  AS year_month_day_code,
        current_timestamp()                                     AS sys_audit_updated_on
    FROM {{ source('stg_ga4','session_info') }}
    WHERE unique_session IS NOT NULL
      AND start_session_date >= DATE '2024-01-01'
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





