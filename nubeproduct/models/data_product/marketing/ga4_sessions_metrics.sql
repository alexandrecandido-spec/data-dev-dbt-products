{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=[
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
      'engage',
      'utm_ad_id'
    ],
    tags=['daily-5am'],
    on_schema_change='fail'
) }}

WITH raw AS (
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
    user_pseudo_id,
    unique_session,
    trial,
    payment,
    session_duration_minutes,
    pageviews_per_session,

    -- extraigo los dígitos entre "id_" y "&utm"
    regexp_extract(landing_page, 'id_([0-9]+)&utm', 1) AS utm_ad_id

  FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}
  WHERE 1 = 1
  {% if is_incremental() %}
    AND date > (
      SELECT COALESCE(MAX(date), DATE '1900-01-01')
      FROM {{ this }}
    )
  {% endif %}
),

metrics AS (
  SELECT
    date,
    source_ga4_classification,
    original_user_country,

    CASE
      WHEN date <= DATE '2024-09-07' THEN
        CASE
          WHEN source_ga4_classification = 'inst-br'
               OR (source_ga4_classification NOT LIKE '%inst%'
                   AND landing_page LIKE '%nuvemshop%')
          THEN 'BR'
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
          ELSE 'Other'
        END
      ELSE
        CASE
          WHEN source_ga4_classification = 'inst-br'
               OR landing_page LIKE '%nuvemshop%' THEN 'BR'
          WHEN original_user_country = 'Argentina' THEN 'AR'
          WHEN original_user_country = 'Mexico' THEN 'MX'
          WHEN original_user_country = 'Chile' THEN 'CL'
          WHEN original_user_country = 'Colombia' THEN 'CO'
          ELSE 'Other'
        END
    END AS classified_country,

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

    COUNT(DISTINCT user_pseudo_id)                             AS distinct_user_count,
    COUNT(DISTINCT unique_session)                             AS distinct_session_count,
    SUM(trial)                                                 AS total_trials,
    SUM(payment)                                               AS total_payments,
    SUM(CASE WHEN engage = 1 THEN 1 ELSE 0 END)                AS total_engagements,
    AVG(CASE WHEN engage = 1 THEN session_duration_minutes END)           AS avg_session_duration_engaged,
    APPROX_PERCENTILE(CASE WHEN engage = 1 THEN session_duration_minutes END, 0.5)
                                                              AS median_session_duration_engaged,
    AVG(CASE WHEN engage = 1 THEN pageviews_per_session END)                AS avg_pageviews_per_session_engaged,
    APPROX_PERCENTILE(CASE WHEN engage = 1 THEN pageviews_per_session END, 0.5)
                                                              AS median_pageviews_per_session_engaged,

    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
  FROM raw
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
    engage,
    utm_ad_id
)

SELECT * FROM metrics









