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
      'team',
      'subteam'
    ],
    tags = ['daily-5am'],
    on_schema_change = 'fail'
) }}

-- 1) Traigo todo lo crudo desde la capa intermedia
WITH raw_data AS (
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
    session_duration_minutes,
    pageviews_per_session,
    trial,
    payment
  FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}
),

-- 2) Calculo classified_country una sola vez por fila
classified AS (
  SELECT
    *,
    CASE
      WHEN date <= DATE '2024-09-07' THEN
        CASE
          WHEN source_ga4_classification = 'inst-br'
               OR (source_ga4_classification NOT LIKE '%inst%' AND landing_page LIKE '%nuvemshop%')
            THEN 'BR'
          WHEN source_ga4_classification = 'inst-ar' THEN 'AR'
          WHEN source_ga4_classification = 'inst-mx' THEN 'MX'
          WHEN source_ga4_classification = 'inst-co' THEN 'CO'
          WHEN source_ga4_classification = 'inst-cl' THEN 'CL'
          WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Argentina' THEN 'AR'
          WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Mexico'    THEN 'MX'
          WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Chile'     THEN 'CL'
          WHEN source_ga4_classification NOT LIKE '%inst%' AND original_user_country = 'Colombia'  THEN 'CO'
          WHEN source_ga4_classification NOT LIKE '%inst%' 
               AND original_user_country NOT IN ('Brazil','Mexico','Argentina','Chile','Colombia')
            THEN 'Other'
          ELSE original_user_country
        END
      ELSE
        CASE
          WHEN source_ga4_classification = 'inst-br' OR landing_page LIKE '%nuvemshop%' THEN 'BR'
          WHEN original_user_country = 'Argentina' THEN 'AR'
          WHEN original_user_country = 'Mexico'    THEN 'MX'
          WHEN original_user_country = 'Chile'     THEN 'CL'
          WHEN original_user_country = 'Colombia'  THEN 'CO'
          WHEN original_user_country NOT IN ('Brazil','Mexico','Argentina','Chile','Colombia')
            THEN 'Other'
          ELSE original_user_country
        END
    END AS classified_country
  FROM raw_data
),

-- 3) Agrego métricas a nivel de combinación de claves
agg AS (
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

    COUNT(DISTINCT user_pseudo_id)     AS distinct_user_count,
    COUNT(DISTINCT unique_session)     AS distinct_session_count,
    SUM(trial)                         AS total_trials,
    SUM(payment)                       AS total_payments,
    SUM(CASE WHEN engage = 1 THEN 1 ELSE 0 END) AS total_engagements,

    AVG(CASE WHEN engage = 1 THEN session_duration_minutes ELSE NULL END) AS avg_session_duration_engaged,
    APPROX_PERCENTILE(CASE WHEN engage = 1 THEN session_duration_minutes ELSE NULL END, 0.5) AS median_session_duration_engaged,
    AVG(CASE WHEN engage = 1 THEN pageviews_per_session ELSE NULL END)   AS avg_pageviews_per_session_engaged,
    APPROX_PERCENTILE(CASE WHEN engage = 1 THEN pageviews_per_session ELSE NULL END, 0.5) AS median_pageviews_per_session_engaged

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
    engage
),

-- 4) Enriquecer con team / subteam usando un solo LATERAL JOIN
enriched AS (
  SELECT
    a.*,
    COALESCE(x.team,   'Others') AS team,
    COALESCE(x.subteam, x.team, 'Others') AS subteam
  FROM agg AS a

  LEFT JOIN LATERAL (
    SELECT
      m.team,
      m.subteam
    FROM {{ ref('inputs_marketing_attribution') }} AS m
    WHERE
      m.state = 'open'
      AND (
        -- 1) Partners directo
        (a.last_source IS NULL
         AND a.last_medium IS NULL
         AND a.last_campaign IS NULL
         AND a.landing_page IN ('partners.tiendanube.com','partners.nuvemshop.com.br'))
        OR
        -- 2) Affiliates por gclid
        (a.landing_page LIKE '%gclid%' AND a.landing_page LIKE '%/partners/%')
        OR
        -- 3) Orgánico buscadores + URL/INSTI
        (a.last_source IN ('yahoo','google','bing')
         AND a.last_medium = 'organic'
         AND a.landing_page LIKE m.landing_page_path
         AND m.input_type IN ('URL','INSTI'))
        OR
        -- 4) Directo + URL/INSTI
        (a.last_source = 'direct'
         AND a.landing_page LIKE m.landing_page_path
         AND m.input_type IN ('URL','INSTI'))
        OR
        -- 5) AI referrers + URL/INSTI
        (a.last_source IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
         AND a.landing_page LIKE m.landing_page_path
         AND m.input_type IN ('URL','INSTI'))
        OR
        -- 6) Match completo UTM
        (a.last_source   = m.utm_source
         AND a.last_medium = m.utm_medium
         AND a.last_campaign = m.utm_campaign
         AND m.input_type IN ('UTM','SUBTEAM_MKT'))
        OR
        -- 7) Match parcial UTM
        (a.last_source = m.utm_source
         AND a.last_medium = m.utm_medium
         AND m.input_type = 'UTM')
        OR
        -- 8) Growth por referrer
        (a.landing_page LIKE m.referrer AND m.input_type = 'REFERRER')
      )
    ORDER BY m.input_number
    LIMIT 1
  ) AS x ON TRUE
)

-- 5) Salida final con auditoría
SELECT
  *,
  CURRENT_TIMESTAMP       AS sys_audit_created_on,
  'data-dev-dbt-products' AS sys_audit_created_by,
  CURRENT_TIMESTAMP       AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM enriched
