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
            SELECT COALESCE(MAX(year_month_day_code), 19000101)
            FROM {{ this }}
          )
      AND sys_audit_updated_on >= (
            SELECT COALESCE(MAX(sys_audit_updated_on),
                            TIMESTAMP '1900-01-01')
            FROM {{ this }}
          )
  {% else %}
    WHERE date >= DATE '2024-01-01'
  {% endif %}
),

source_data AS (
  SELECT *
  FROM attribution_int
)


SELECT
   sd.* EXCEPT(
      row_hash,
      sys_audit_created_on, sys_audit_created_by,
      sys_audit_updated_on, sys_audit_updated_by
  ),

  MD5(
    CONCAT(
      COALESCE(CAST(sd.year_month_day_code AS STRING), ''), '|',
      COALESCE(CAST(sd.date                AS STRING), ''), '|',
      COALESCE(sd.source_ga4_classification, ''), '|',
      COALESCE(sd.original_user_country    , ''), '|',
      COALESCE(sd.classified_country       , ''), '|',
      COALESCE(sd.env                      , ''), '|',
      COALESCE(sd.landing_page             , ''), '|',
      COALESCE(sd.landing_page_domain      , ''), '|',
      COALESCE(sd.landing_page_path        , ''), '|',
      COALESCE(sd.last_source              , ''), '|',
      COALESCE(sd.last_medium              , ''), '|',
      COALESCE(sd.last_campaign            , ''), '|',
      COALESCE(sd.first_event_device       , ''), '|',
      COALESCE(sd.last_event_device        , ''), '|',
      COALESCE(CAST(sd.only_login_session  AS STRING), ''), '|',
      COALESCE(sd.user_type                , ''), '|',
      COALESCE(sd.session_status           , ''), '|',
      COALESCE(sd.utm_ad_id                , ''), '|',
      COALESCE(sd.utm_content              , ''), '|',
      COALESCE(sd.utm_term                 , ''), '|',
      COALESCE(sd.mkt_source               , ''), '|',
      COALESCE(sd.mkt_subteam              , '')
    )
  )                                                  AS row_hash,

  current_timestamp()     AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp()     AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

FROM source_data sd
{% if not is_incremental() %}
  WHERE sd.date >= DATE '2024-01-01'
{% endif %}















































