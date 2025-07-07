{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    partition_by         = ['year_month_day_code'],
    cluster_by           = ['year_month_day_code'],     
        unique_key = [
        'year_month_day_code','date',
        'source_ga4_classification','original_user_country','classified_country',
        'env','landing_page','landing_page_domain','landing_page_path',
        'last_source','last_medium','last_campaign',
        'first_event_device','last_event_device','only_login_session',
        'user_type','session_status','utm_ad_id'
    ],
    on_schema_change     = 'sync_all_columns',
    tags                 = ['daily-5am']
) }}

WITH prepared AS (
  SELECT
    *,
    CASE WHEN engage = 1 THEN 'Engaged' ELSE 'Bounced' END AS session_status,
    REGEXP_EXTRACT(landing_page, '^https?://([^/]+)', 1)       AS landing_page_domain,
    REGEXP_EXTRACT(landing_page, '^https?://[^/]+(/[^?]*)', 1) AS landing_page_path
  FROM {{ ref('marketing_ga4_sessions_classified') }}
  {% if is_incremental() %}
    WHERE year_month_day_code
          >= CAST(date_format(date_sub(current_date(), 3), 'yyyyMMdd') AS int)
  {% endif %}
),

aggregated AS (
  SELECT
    date,
    year_month_day_code,
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

    COUNT(DISTINCT user_pseudo_id)                                 AS distinct_user_count,
    COUNT(DISTINCT unique_session)                                 AS distinct_session_count,
    SUM(trial)                                                     AS total_trials,
    SUM(payment)                                                   AS total_payments,
    SUM(CASE WHEN session_status = 'Engaged' THEN 1 END)           AS total_engagements,
    AVG(CASE WHEN session_status = 'Engaged' THEN session_duration_minutes END)            AS avg_session_duration,
    APPROX_PERCENTILE(CASE WHEN session_status = 'Engaged' THEN session_duration_minutes END, 0.5) AS median_session_duration,
    AVG(CASE WHEN session_status = 'Engaged' THEN pageviews_per_session END)                 AS avg_pageviews_per_session,
    APPROX_PERCENTILE(CASE WHEN session_status = 'Engaged' THEN pageviews_per_session END, 0.5)     AS median_pageviews_per_session
  FROM prepared
  GROUP BY
    date, year_month_day_code,
    source_ga4_classification, original_user_country, classified_country,
    env, landing_page, landing_page_domain, landing_page_path,
    last_source, last_medium, last_campaign,
    first_event_device, last_event_device,
    only_login_session, user_type, session_status, utm_ad_id
)

SELECT *,
current_timestamp()       AS sys_audit_created_on,
'data-dev-dbt-products'   AS sys_audit_created_by,
current_timestamp()       AS sys_audit_updated_on,
'data-dev-dbt-products'   AS sys_audit_updated_by
FROM aggregated

{% if not is_incremental() %}
  WHERE date >= DATE '2024-01-01'
{% endif %}



