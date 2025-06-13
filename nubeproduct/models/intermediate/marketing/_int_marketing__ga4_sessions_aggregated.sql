-- 1) Raw base from ga4 sessions with dimensions
WITH
base AS (
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
      utm_ad_id,
      user_pseudo_id,
      unique_session,
      trial,
      payment,
      session_duration_minutes,
      pageviews_per_session
  FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}
),

-- 2) Engagement status based on 'engage' field
session_status AS (
  SELECT
    *,
    CASE WHEN engage = 1 THEN 'Engaged' ELSE 'Bounced' END AS session_status
  FROM base
),

-- 3) Country classification logic
classified AS (
  SELECT
    session_status.*, 
    CASE
      WHEN date <= DATE '2024-09-07' THEN
        CASE
          WHEN source_ga4_classification = 'inst-br'
               OR (source_ga4_classification NOT LIKE '%inst%' AND landing_page LIKE '%nuvemshop%') THEN 'BR'
          WHEN source_ga4_classification = 'inst-ar' THEN 'AR'
          WHEN source_ga4_classification = 'inst-mx' THEN 'MX'
          WHEN source_ga4_classification = 'inst-co' THEN 'CO'
          WHEN source_ga4_classification = 'inst-cl' THEN 'CL'
          WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Argentina' THEN 'AR'
          WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Mexico' THEN 'MX'
          WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Chile' THEN 'CL'
          WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Colombia' THEN 'CO'
          WHEN source_ga4_classification NOT LIKE '%inst%'
               AND original_user_country NOT IN ('Brazil','Mexico','Argentina','Chile','Colombia') THEN 'Other'
          ELSE original_user_country
        END
      ELSE
        CASE
          WHEN source_ga4_classification = 'inst-br' OR landing_page LIKE '%nuvemshop%' THEN 'BR'
          WHEN original_user_country = 'Argentina' THEN 'AR'
          WHEN original_user_country = 'Mexico' THEN 'MX'
          WHEN original_user_country = 'Chile' THEN 'CL'
          WHEN original_user_country = 'Colombia' THEN 'CO'
          WHEN original_user_country NOT IN ('Brazil','Mexico','Argentina','Chile','Colombia') THEN 'Other'
          ELSE original_user_country
        END
    END AS classified_country
  FROM session_status
),

-- 4) Agregation of sessions and metrics
aggregated AS (
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
    session_status,
    utm_ad_id,
    COUNT(DISTINCT user_pseudo_id) AS distinct_user_count,
    COUNT(DISTINCT unique_session) AS distinct_session_count,
    SUM(trial) AS total_trials,
    SUM(payment) AS total_payments,
    SUM(CASE WHEN session_status = 'Engaged' THEN 1 ELSE 0 END) AS total_engagements,
    AVG(CASE WHEN session_status = 'Engaged' THEN session_duration_minutes END) AS avg_session_duration,
    APPROX_PERCENTILE(CASE WHEN session_status = 'Engaged' THEN session_duration_minutes END, 0.5) AS median_session_duration,
    AVG(CASE WHEN session_status = 'Engaged' THEN pageviews_per_session END) AS avg_pageviews_per_session,
    APPROX_PERCENTILE(CASE WHEN session_status = 'Engaged' THEN pageviews_per_session END, 0.5) AS median_pageviews_per_session
  FROM classified
  GROUP BY
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
    utm_ad_id
)

-- 5) final selection of aggregated data
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
  median_pageviews_per_session
FROM aggregated