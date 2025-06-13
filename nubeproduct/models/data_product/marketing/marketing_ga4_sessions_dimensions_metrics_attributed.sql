{{ config(
  materialized = 'incremental',
  incremental_strategy = 'merge',
  unique_key = [
    'date',
    'source_ga4_classification',
    'original_user_country',
    'classified_country',
    'env',
    'landing_page',
    'last_source',
    'last_medium',
    'last_campaign',
    'first_event_device',
    'last_event_device',
    'only_login_session',
    'user_type',
    'session_status',
    'utm_ad_id',
    'mkt_source',
    'mkt_subteam',
    'year_month_code'
  ],
  partition_by = ['year_month_code'],
  tags = ['daily-5am'],
  on_schema_change = 'fail'
) }}

-- Data Product layer: incremental merge from classified sessions aggregated by dimensions
SELECT
  date,
  year(date) * 100 + month(date) AS year_month_code,
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
  current_timestamp() AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  current_timestamp() AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_marketing__ga4_sessions_attribution') }} src
{% if is_incremental() %}
  WHERE year(src.date) * 100 + month(src.date) > 
    (SELECT max(year_month_code) FROM {{ this }})
{% endif %}