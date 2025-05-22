{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'unique_session',
    partition_by = ['year_month_code'],
    tags = ['daily-5am'],
    on_schema_change = 'fail'
) }}

SELECT
    mpv_event_timestamp AS event_timestamp,
    event_date_parsed AS event_date,
    CAST(to_char(event_date_parsed, 'yyyyMM') AS STRING) AS year_month_code,
    user_pseudo_id,
    unique_session,
    source AS source_ga4_classification,
    mpv_country AS original_user_country,
    mpv_env AS env_pagegroup,
    mpv_landing_page AS landing_page,
    mpv_last_source AS last_source,
    mpv_last_medium AS last_medium,
    mpv_last_campaign AS last_campaign,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_ga4', 'mod_pv_info') }}
WHERE 1=1
AND unique_session IS NOT NULL
  {% if not is_incremental() %}
    AND event_date_parsed >= DATE '2024-01-01'
  {% endif %}

  {% if is_incremental() %}
    AND sys_audit_updated_on >= (SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01') FROM {{ this }})
  {% endif %}

  AND source <> 'ecosystem'


