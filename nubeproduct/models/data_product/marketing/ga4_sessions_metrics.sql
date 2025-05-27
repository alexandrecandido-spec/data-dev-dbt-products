{{ config(
  materialized = 'incremental',
  incremental_strategy = 'merge',
  partition_by = ['date'],
  unique_key = [
    'date','source_ga4_classification','original_user_country','classified_country',
    'env','landing_page','last_source','last_medium','last_campaign',
    'first_event_device','last_event_device','only_login_session','user_type','engage'
  ],
  tags=['daily-5am'],
  on_schema_change='fail'
) }}

WITH base AS (
  SELECT
    date,
    source_ga4_classification,
    original_user_country,
    env,
    landing_page,
    last_source,
    last_medium,
    last_campaign,
    first_event_device,
    last_event_device,
    only_login_session,
    user_type,
    engage,
    -- Clasificación de país
    CASE
      WHEN date <= DATE '2024-09-07' THEN
        CASE
          WHEN source_ga4_classification = 'inst-br'
               OR (source_ga4_classification NOT LIKE '%inst%'
                   AND landing_page LIKE '%nuvemshop.com%') THEN 'BR'
          WHEN source_ga4_classification = 'inst-ar' THEN 'AR'
          WHEN source_ga4_classification = 'inst-mx' THEN 'MX'
          WHEN source_ga4_classification = 'inst-co' THEN 'CO'
          WHEN source_ga4_classification = 'inst-cl' THEN 'CL'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country = 'Argentina' THEN 'AR'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country = 'Mexico' THEN 'MX'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country = 'Chile' THEN 'CL'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country = 'Colombia' THEN 'CO'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country NOT IN ('Brazil','Mexico','Argentina','Chile','Colombia') THEN 'Other'
          ELSE original_user_country
        END
      ELSE
        CASE
          WHEN source_ga4_classification = 'inst-br'
               OR landing_page LIKE '%nuvemshop.com%' THEN 'BR'
          WHEN original_user_country = 'Argentina' THEN 'AR'
          WHEN original_user_country = 'Mexico' THEN 'MX'
          WHEN original_user_country = 'Chile' THEN 'CL'
          WHEN original_user_country = 'Colombia' THEN 'CO'
          WHEN original_user_country NOT IN ('Brazil','Mexico','Argentina','Chile','Colombia') THEN 'Other'
          ELSE original_user_country
        END
    END AS classified_country,
    user_pseudo_id,
    unique_session,
    session_duration_minutes,
    pageviews_per_session,
    trial,
    payment
  FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}
  {% if is_incremental() %}
    WHERE date > (
      SELECT COALESCE(MAX(date), DATE '1900-01-01') FROM {{ this }}
    )
  {% endif %}
),
metrics AS (
  SELECT
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
    engage,
    COUNT(DISTINCT user_pseudo_id) AS distinct_user_count,
    COUNT(DISTINCT unique_session) AS distinct_session_count,
    SUM(trial) AS total_trials,
    SUM(payment) AS total_payments,
    SUM(CASE WHEN engage = 1 THEN 1 ELSE 0 END) AS total_engagements,
    AVG(CASE WHEN engage = 1 THEN session_duration_minutes ELSE NULL END) AS avg_session_duration_engaged,
    APPROX_PERCENTILE(CASE WHEN engage = 1 THEN session_duration_minutes ELSE NULL END, 0.5) AS median_session_duration_engaged,
    AVG(CASE WHEN engage = 1 THEN pageviews_per_session ELSE NULL END) AS avg_pageviews_per_session_engaged,
    APPROX_PERCENTILE(CASE WHEN engage = 1 THEN pageviews_per_session ELSE NULL END, 0.5) AS median_pageviews_per_session_engaged,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
  FROM base
  GROUP BY
    date, source_ga4_classification, original_user_country, classified_country,
    env, landing_page, last_source, last_medium, last_campaign,
    first_event_device, last_event_device, only_login_session, user_type, engage
)

SELECT *
FROM metrics


