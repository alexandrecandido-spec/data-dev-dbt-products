{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  partition_by=['year_month_day_code'],
  unique_key=['unique_session','event_timestamp','user_pseudo_id'],
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
    'unique_session','event_timestamp','user_pseudo_id',
    'sys_audit_created_on','sys_audit_created_by'
  ]) }}
)

SELECT 
    src.mpv_event_timestamp         AS event_timestamp,
    src.event_date_parsed           AS event_date,
    CAST(date_format(src.event_date_parsed,'yyyyMMdd') AS INT) AS year_month_day_code,

    src.user_pseudo_id,
    src.unique_session,
    src.source                      AS source_ga4_classification,
    src.mpv_country                 AS original_user_country,
    src.mpv_env                     AS env_pagegroup,
    src.mpv_landing_page            AS landing_page,

    REGEXP_EXTRACT(COALESCE(src.mpv_landing_page, src.mpv_page), '^https?://([^/]+)', 1)        AS landing_page_domain,
    REGEXP_EXTRACT(COALESCE(src.mpv_landing_page, src.mpv_page), '^https?://[^/]+(/[^?]*)', 1)  AS landing_page_path,

    src.mpv_last_source             AS last_source,
    src.mpv_last_medium             AS last_medium,
    src.mpv_last_campaign           AS last_campaign,

    REGEXP_EXTRACT(COALESCE(src.mpv_landing_page, src.mpv_page), 'utm_term=([^&]+)', 1)    AS utm_term,
    REGEXP_EXTRACT(COALESCE(src.mpv_landing_page, src.mpv_page), 'utm_content=([^&]+)', 1) AS utm_content,
    REGEXP_EXTRACT(COALESCE(src.mpv_landing_page, src.mpv_page), 'id_([^&]+)', 1)          AS utm_ad_id,

    COALESCE(e.sys_audit_created_on, current_timestamp)       AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp                                          AS sys_audit_updated_on,
    'data-dev-dbt-products'                                    AS sys_audit_updated_by
FROM {{ ref('marketing_mod_pv_info') }} src
CROSS JOIN baseline b
LEFT JOIN existing_data e
  ON  src.unique_session      = e.unique_session
  AND src.mpv_event_timestamp = e.event_timestamp
  AND src.user_pseudo_id      = e.user_pseudo_id
WHERE src.unique_session       IS NOT NULL
  AND src.user_pseudo_id       IS NOT NULL
  AND src.mpv_event_timestamp  IS NOT NULL
  AND COALESCE(src.source,'') <> 'ecosystem'
  AND src.event_date_parsed    >= DATE '2024-01-01'
  {% if is_incremental() %}
  AND (
        src.event_date_parsed >= date_sub(date(b.last_upd), 5)
     OR src.sys_audit_updated_on >= b.last_upd - INTERVAL 5 DAY
      )
  {% endif %}
