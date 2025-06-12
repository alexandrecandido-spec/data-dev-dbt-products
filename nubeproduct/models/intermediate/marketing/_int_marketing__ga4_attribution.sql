WITH source AS (
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
    utm_ad_id
  FROM {{ ref('ga4_sessions_metrics') }}
),

subteam_attr AS (
  SELECT
    utm_source,
    utm_medium,
    utm_campaign,
    team        AS subteam_team,
    subteam     AS subteam_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'UTM_SUBTEAM'
),

utm_attr AS (
  SELECT
    utm_source,
    utm_medium,
    team        AS utm_team,
    subteam     AS utm_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'UTM'
),

url_attr AS (
  SELECT
    url,
    team        AS url_team,
    subteam     AS url_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type ='URL'
),

inst_attr AS (
  SELECT
    landing_page_path,
    team        AS inst_team,
    subteam     AS inst_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type ='INSTI'
),

ref_attr AS (
  SELECT
    referrer,
    team        AS ref_team,
    subteam     AS ref_subteam
  FROM {{ ref('inputs_marketing_attribution') }}
  WHERE input_type = 'REFERRER'
)

SELECT
  s.*,
  COALESCE(sub.subteam_team, u.utm_team, 'Others')      AS utm_team,
  COALESCE(sub.subteam_subteam, u.utm_subteam, 'Others') AS utm_subteam,
  ur.url_team,
  ur.url_subteam,
  ins.url_team,
  ins.url_subteam,
  rf.ref_team,
  rf.ref_subteam
FROM source s

-- Join sobre UTM_SUBTEAM
LEFT JOIN subteam_attr sub
  ON s.last_source   = sub.utm_source
 AND s.last_medium   = sub.utm_medium
 AND s.last_campaign = sub.utm_campaign

-- Fallback UTM 
LEFT JOIN utm_attr url
  ON s.last_source   = u.utm_source
 AND s.last_medium   = u.utm_medium

-- URL sigue sólo sobre landing_page
LEFT JOIN url_attr ur
  ON s.landing_page LIKE ur.url


-- INSTI sigue sólo sobre landing_page
LEFT JOIN url_inst_attr ins
  ON s.landing_page LIKE ins.landing_page_path

-- REFERRER sobre landing_page
LEFT JOIN ref_attr rf
  ON s.landing_page LIKE rf.referrer


