

WITH dims AS (
  SELECT DISTINCT
    date, source_ga4_classification, original_user_country,
    classified_country, env, landing_page,
    last_source, last_medium, last_campaign,
    first_event_device, last_event_device,
    only_login_session, user_type, engage
  FROM {{ ref('ga4_sessions_metrics') }}
),

utm_subteam AS (
  SELECT
    utm_source, utm_medium, utm_campaign,
    team   AS utm_team,
    subteam AS utm_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'UTM_SUBTEAM'
),

utm AS (
  SELECT
    utm_source, utm_medium,
    team   AS utm_simple_team,
    subteam AS utm_simple_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'UTM'
),

url_insti AS (
  SELECT
    landing_page_path,
    team   AS url_team,
    subteam AS url_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type IN ('URL','INSTI')
),

referr AS (
  SELECT
    referrer,
    team     AS ref_team,
    subteam  AS ref_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'REFERRER'
)

SELECT
  d.*,

  -- expongo las columnas de inputs para poder usarlas en el DP
  us.utm_source    AS utm_source,
  us.utm_medium    AS utm_medium,
  us.utm_campaign  AS utm_campaign,

  u.utm_source     AS utm_simple_source,
  u.utm_medium     AS utm_simple_medium,

  rf.referrer      AS referrer,

  -- y por supuesto los equipos/subequipos
  us.utm_team,
  us.utm_subteam,
  u.utm_simple_team,
  u.utm_simple_subteam,
  ui.url_team,
  ui.url_subteam,
  rf.ref_team,
  rf.ref_subteam

FROM dims d
LEFT JOIN utm_subteam us
  ON d.last_source  = us.utm_source
 AND d.last_medium  = us.utm_medium
 AND d.last_campaign= us.utm_campaign

LEFT JOIN utm u
  ON d.last_source = u.utm_source
 AND d.last_medium = u.utm_medium

LEFT JOIN url_insti ui
  ON d.landing_page LIKE '%' || ui.landing_page_path || '%'

LEFT JOIN referr rf
  ON d.landing_page LIKE '%' || rf.referrer || '%'