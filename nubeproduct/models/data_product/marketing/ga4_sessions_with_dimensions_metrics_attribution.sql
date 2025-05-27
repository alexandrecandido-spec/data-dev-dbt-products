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
      'engage',
      'utm_team',
      'utm_subteam',
      'url_team',
      'url_subteam',
      'ref_team',
      'ref_subteam'
    ],
    tags = ['daily-5am'],
    on_schema_change = 'fail'
) }}

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
    user_pseudo_id,
    unique_session,
    trial,
    payment,
    session_duration_minutes,
    pageviews_per_session
  FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}
  WHERE 1 = 1
  {% if is_incremental() %}
    AND date > (
      SELECT COALESCE(MAX(date), DATE '1900-01-01')
      FROM {{ this }}
    )
  {% endif %}
),


aggregated AS (
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

  FROM base
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
    engage
),

-- 1) Inputs de SUBTEAM_MKT (prioridad)
subteam_attr AS (
  SELECT
    utm_source,
    utm_medium,
    team    AS subteam_team,
    subteam AS subteam_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'UTM_SUBTEAM'
),

-- 2) Inputs de UTM (fallback)
utm_attr AS (
  SELECT
    utm_source,
    utm_medium,
    team    AS utm_team,
    subteam AS utm_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'UTM'
),

-- 3) Inputs URL/INSTI
url_inst_attr AS (
  SELECT
    landing_page_path,
    team    AS url_team,
    subteam AS url_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type IN ('URL','INSTI')
),

-- 4) Inputs REFERRER
ref_attr AS (
  SELECT
    referrer,
    team    AS ref_team,
    subteam AS ref_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'REFERRER'
)

-- 5) Unión final: métricas + atribución
SELECT
  m.*,
  COALESCE(s.subteam_team, u.utm_team,   'Others')   AS utm_team,
  COALESCE(s.subteam_subteam, u.utm_subteam, 'Others') AS utm_subteam,
  ui.url_team,
  ui.url_subteam,
  rf.ref_team,
  rf.ref_subteam
FROM aggregated m
LEFT JOIN subteam_attr s
  ON m.last_source = s.utm_source
 AND m.last_medium = s.utm_medium
LEFT JOIN utm_attr u
  ON m.last_source = u.utm_source
 AND m.last_medium = u.utm_medium
LEFT JOIN url_inst_attr ui
  ON m.landing_page LIKE ui.landing_page_path
LEFT JOIN ref_attr rf
  ON m.landing_page LIKE rf.referrer









