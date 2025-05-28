{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=[
      'date','source_ga4_classification','original_user_country','classified_country',
      'env','landing_page','last_source','last_medium','last_campaign',
      'first_event_device','last_event_device','only_login_session',
      'user_type','engage','utm_team','utm_subteam','url_team',
      'url_subteam','ref_team','ref_subteam'
    ],
    tags=['daily-5am'],
    on_schema_change='fail'
) }}

SELECT
  m.*,
  a.utm_team,
  a.utm_subteam,
  a.url_team,
  a.url_subteam,
  a.ref_team,
  a.ref_subteam
FROM {{ ref('ga4_sessions_metrics') }} m
LEFT JOIN {{ ref('_int_marketing__ga4_attribution') }} a
  USING (
    date, source_ga4_classification, original_user_country, classified_country,
    env, landing_page, last_source, last_medium, last_campaign
  )