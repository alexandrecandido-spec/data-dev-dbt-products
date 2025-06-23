{{ 
  config(
    materialized          = 'incremental',
    incremental_strategy  = 'merge',
    partition_by          = ['year_month_day_code'],
    cluster_by            = ['year_month_day_code','session_status'],
    incremental_predicates= [
      "year_month_day_code >= CAST(date_format(date_sub(current_date(), 3), 'yyyyMMdd') AS INT)"
    ],
    unique_key            = ['row_hash'],
    on_schema_change      = 'sync_all_columns',
    tags                  = ['daily-5am']
  ) 
}}

--------------------------------------------------------------------------------
-- 1) Source CTE: pull only the columns you need + create a single merge key
--------------------------------------------------------------------------------
WITH source_data AS (
  SELECT
    -- daily partition key
    CAST(date_format(date, 'yyyyMMdd') AS INT) AS year_month_day_code,
    date,

    source_ga4_classification,
    original_user_country,
    classified_country,
    env,
    landing_page,
    last_source,
    last_medium,
    last_campaign,
    first_event_device,
    last_event_device,
    only_login_session,
    user_type,
    session_status,
    utm_ad_id,

    distinct_user_count,
    distinct_session_count,
    total_trials,
    total_payments,
    total_engagements,
    avg_session_duration,
    median_session_duration,
    avg_pageviews_per_session,
    median_pageviews_per_session,

    mkt_source,
    mkt_subteam,

    -- single MD5 hash of all dimensions = one easy unique_key
    md5(concat_ws('||',
      CAST(date_format(date,'yyyyMMdd') AS INT),
      source_ga4_classification,
      original_user_country,
      classified_country,
      env,
      landing_page,
      last_source,
      last_medium,
      last_campaign,
      first_event_device,
      last_event_device,
      only_login_session,
      user_type,
      session_status,
      utm_ad_id,
      mkt_source,
      mkt_subteam
    )) AS row_hash

  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
)

--------------------------------------------------------------------------------
-- 2) Final SELECT drives the MERGE—only one source alias, no ambiguity
--------------------------------------------------------------------------------
SELECT
  year_month_day_code,
  CAST(year_month_day_code / 100 AS INT) AS year_month_code,
  date,

  source_ga4_classification,
  original_user_country,
  classified_country,
  env,
  landing_page,
  last_source,
  last_medium,
  last_campaign,
  first_event_device,
  last_event_device,
  only_login_session,
  user_type,
  session_status,
  utm_ad_id,

  distinct_user_count,
  distinct_session_count,
  total_trials,
  total_payments,
  total_engagements,
  avg_session_duration,
  median_session_duration,
  avg_pageviews_per_session,
  median_pageviews_per_session,

  mkt_source,
  mkt_subteam,

  row_hash,

  -- audit columns
  current_timestamp()     AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp()     AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by

FROM source_data






















