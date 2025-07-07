{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    partition_by = ['year_month_day_code'],
    cluster_by = ['year_month_day_code', 'session_status'],
    unique_key = ['row_hash'],
    on_schema_change = 'sync_all_columns',
    tags = ['daily-5am']
  )
}}

WITH source_data AS (
  SELECT
    year_month_day_code,
    date,
    source_ga4_classification,
    original_user_country,
    classified_country,
    env,
    landing_page,
    landing_page_domain,
    landing_page_path,
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
    sys_audit_updated_on
  FROM {{ ref('_int_marketing__ga4_sessions_attribution') }}
  {% if is_incremental() %}
    WHERE year_month_day_code >= (
      SELECT COALESCE(MAX(year_month_day_code), 19000101)
      FROM {{ this }}
    )
    AND sys_audit_updated_on >= (
      SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
      FROM {{ this }}
    )
  {% else %}
    WHERE date >= DATE '2024-01-01'
  {% endif %}
)

SELECT
  year_month_day_code,
  CAST(year_month_day_code / 100 AS INT) AS year_month_code,
  date,
  source_ga4_classification,
  original_user_country,
  classified_country,
  env,
  landing_page,
  landing_page_domain,
  landing_page_path,
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
  current_timestamp() AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp() AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data
{% if not is_incremental() %}
  WHERE date >= DATE '2024-01-01'
{% endif %}





























