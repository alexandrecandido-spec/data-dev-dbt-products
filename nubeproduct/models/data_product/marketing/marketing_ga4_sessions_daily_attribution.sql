
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    cluster_by           = ['year_month_day_code','session_status'],
    unique_key           = ['row_hash'],
    on_schema_change     = 'sync_all_columns',
    tags                 = ['daily-5am']
) }}

WITH attribution_int AS (
  SELECT *
  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
  {% if is_incremental() %}
    WHERE year_month_day_code >= (
      SELECT COALESCE(MAX(year_month_day_code), 19000101) FROM {{ this }}
    )
      AND sys_audit_updated_on >= (
      SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') FROM {{ this }}
    )
  {% else %}
    WHERE date >= DATE '2024-01-01'
  {% endif %}
),

source_data AS (
  SELECT src.*  
  FROM attribution_int AS src
)

SELECT
  *,
  MD5(
    CONCAT(
      COALESCE(CAST(year_month_day_code     AS STRING), ''), '|',
      COALESCE(CAST(date                    AS STRING), ''), '|',
      COALESCE(source_ga4_classification    , ''), '|',
      COALESCE(original_user_country        , ''), '|',
      COALESCE(classified_country           , ''), '|',
      COALESCE(env                          , ''), '|',
      COALESCE(landing_page                 , ''), '|',
      COALESCE(landing_page_domain          , ''), '|',
      COALESCE(landing_page_path            , ''), '|',
      COALESCE(last_source                  , ''), '|',
      COALESCE(last_medium                  , ''), '|',
      COALESCE(last_campaign                , ''), '|',
      COALESCE(first_event_device           , ''), '|',
      COALESCE(last_event_device            , ''), '|',
      COALESCE(CAST(only_login_session      AS STRING), ''), '|',
      COALESCE(user_type                    , ''), '|',
      COALESCE(session_status               , ''), '|',
      COALESCE(utm_ad_id                    , ''), '|',
      COALESCE(utm_content                  , ''), '|',
      COALESCE(utm_term                     , ''), '|',
      COALESCE(mkt_source                   , ''), '|',
      COALESCE(mkt_subteam                  , '')
    )
  ) AS row_hash,
  current_timestamp()     AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp()     AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

FROM source_data
{% if not is_incremental() %}
  WHERE date >= DATE '2024-01-01'
{% endif %}















































