{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    partition_by=['year_month_day_code'],
    unique_key=['unique_session','event_timestamp','user_pseudo_id'],
    on_schema_change='fail',
    tags=['daily-6am','marketing']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, [
    'unique_session','event_timestamp','user_pseudo_id',
    'sys_audit_created_on','sys_audit_created_by'
  ]) }}
),

src AS (
    SELECT
        mpv_event_timestamp         AS event_timestamp,                 
        event_date_parsed           AS event_date,                       
        CAST(date_format(event_date_parsed,'yyyyMMdd') AS INT) AS year_month_day_code,

        user_pseudo_id,
        unique_session,
        source                      AS source_ga4_classification,
        mpv_country                 AS original_user_country,
        mpv_env                     AS env_pagegroup,
        mpv_landing_page            AS landing_page,

        REGEXP_EXTRACT(mpv_landing_page, '^https?://([^/]+)', 1)        AS landing_page_domain,
        REGEXP_EXTRACT(mpv_landing_page, '^https?://[^/]+(/[^?]*)', 1)  AS landing_page_path,

        mpv_last_source             AS last_source,
        mpv_last_medium             AS last_medium,
        mpv_last_campaign           AS last_campaign,

        REGEXP_EXTRACT(mpv_landing_page, 'utm_term=([^&]+)', 1)    AS utm_term,
        REGEXP_EXTRACT(mpv_landing_page, 'utm_content=([^&]+)', 1) AS utm_content,
        REGEXP_EXTRACT(mpv_landing_page, 'id_([^&]+)', 1)          AS utm_ad_id,

        sys_audit_updated_on
    FROM {{ source('stg_ga4','mod_pv_info') }}
    WHERE unique_session IS NOT NULL
      AND user_pseudo_id IS NOT NULL
      AND mpv_event_timestamp IS NOT NULL
      AND source <> 'ecosystem'
      AND event_date_parsed >= DATE '2024-01-01'
),

filtered AS (
  SELECT * FROM src
  {% if is_incremental() %}
  WHERE sys_audit_updated_on >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01 00:00:00')
    FROM {{ this }}
  ) - INTERVAL 5 MINUTES
  {% endif %}
)

SELECT 
    f.event_timestamp,
    f.event_date,
    f.year_month_day_code,
    f.user_pseudo_id,
    f.unique_session,
    f.source_ga4_classification,
    f.original_user_country,
    f.env_pagegroup,
    f.landing_page,
    f.landing_page_domain,
    f.landing_page_path,
    f.last_source,
    f.last_medium,
    f.last_campaign,
    f.utm_term,
    f.utm_content,
    f.utm_ad_id,
    COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp                                          AS sys_audit_updated_on,
    'data-dev-dbt-products'                                    AS sys_audit_updated_by
FROM filtered f
LEFT JOIN existing_data e
  ON  f.unique_session  <=> e.unique_session
  AND f.event_timestamp <=> e.event_timestamp
  AND f.user_pseudo_id  <=> e.user_pseudo_id