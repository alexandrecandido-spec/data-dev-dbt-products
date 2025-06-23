{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    unique_key           = ['unique_session','event_timestamp','user_pseudo_id'],
    on_schema_change     = 'sync_all_columns',
    tags                 = ['daily-5am']
) }}

WITH base AS (
    SELECT
        mpv_event_timestamp                                        AS event_timestamp,
        event_date_parsed                                          AS event_date,
        CAST(date_format(event_date_parsed,'yyyyMMdd') AS int)     AS year_month_day_code,

        user_pseudo_id,
        unique_session,
        source                    AS source_ga4_classification,
        mpv_country               AS original_user_country,
        mpv_env                   AS env_pagegroup,
        mpv_landing_page          AS landing_page,
        mpv_last_source           AS last_source,
        mpv_last_medium           AS last_medium,
        mpv_last_campaign         AS last_campaign,
        current_timestamp()       AS sys_audit_updated_on
    FROM {{ source('stg_ga4','mod_pv_info') }}
    WHERE unique_session IS NOT NULL
      AND source <> 'ecosystem'
      AND event_date_parsed >= DATE '2024-01-01'
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


