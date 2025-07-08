WITH source_data AS (
  SELECT

    REGEXP_REPLACE(
      src.landing_page_domain,
      '^(?:https?://)?(?:www\.)?',
      ''
    ) AS domain_clean,
    src.landing_page_path AS path_clean

  FROM {{ ref('_int_marketing__ga4_sessions_aggregated') }} AS src
),

inputs_url AS (
  SELECT landing_page_domain, landing_page_path, team AS url_team, subteam AS url_subteam
  FROM {{ ref('marketing_inputs_attribution__url') }}
),

inputs_insti AS (
  SELECT landing_page_domain, landing_page_path, team AS insti_team, subteam AS insti_subteam
  FROM {{ ref('marketing_inputs_attribution__insti') }}
),

utm AS (
  SELECT source AS utm_source, medium AS utm_medium, source_mkt, subteam AS utm_subteam
  FROM {{ ref('marketing_inputs_attribution__utm') }}
),

sub_cam AS (
  SELECT utm_source, utm_medium, utm_campaign, subteam
  FROM {{ ref('marketing_inputs_attribution__subteam') }}
)

SELECT
  sd.*,               
  sd.domain_clean,
  sd.path_clean,

  /* ──────────── MKT SOURCE ──────────── */
  CASE
    WHEN sd.last_source = 'direct'
         AND sd.last_medium IS NULL
         AND sd.last_campaign IS NULL
         AND sd.domain_clean IN ('partners.tiendanube.com','partners.nuvemshop.com.br')
      THEN 'Partners'
    WHEN sd.last_source IN ('yahoo','google','bing')
         AND sd.last_medium = 'organic'
         AND EXISTS (
           SELECT 1
           FROM inputs_url u
           WHERE sd.domain_clean = u.landing_page_domain
             AND sd.path_clean   = u.landing_page_path
         )
      THEN (
        SELECT u.url_team
        FROM inputs_url u
        WHERE sd.domain_clean = u.landing_page_domain
          AND sd.path_clean   = u.landing_page_path
        LIMIT 1
      )
    WHEN sd.last_source IN ('yahoo','google','bing')
         AND sd.last_medium = 'organic'
         AND EXISTS (
           SELECT 1
           FROM inputs_insti i
           WHERE sd.domain_clean = i.landing_page_domain
             AND sd.path_clean   = i.landing_page_path
         )
      THEN (
        SELECT i.insti_team
        FROM inputs_insti i
        WHERE sd.domain_clean = i.landing_page_domain
          AND sd.path_clean   = i.landing_page_path
        LIMIT 1
      )
    WHEN sd.last_source IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
         AND EXISTS (
           SELECT 1
           FROM inputs_url u
           WHERE sd.domain_clean = u.landing_page_domain
             AND sd.path_clean   = u.landing_page_path
         )
      THEN (
        SELECT u.url_team
        FROM inputs_url u
        WHERE sd.domain_clean = u.landing_page_domain
          AND sd.path_clean   = u.landing_page_path
        LIMIT 1
      )
    WHEN sd.last_source IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
         AND EXISTS (
           SELECT 1
           FROM inputs_insti i
           WHERE sd.domain_clean = i.landing_page_domain
             AND sd.path_clean   = i.landing_page_path
         )
      THEN (
        SELECT i.insti_team
        FROM inputs_insti i
        WHERE sd.domain_clean = i.landing_page_domain
          AND sd.path_clean   = i.landing_page_path
        LIMIT 1
      )
    WHEN utm.source_mkt = 'Communications' THEN 'Communications'
    WHEN utm.source_mkt = 'Performance'
         AND sd.last_source IN ('google','bing')
         AND POSITION('-brand' IN sd.last_campaign) > 0
      THEN 'Performance Brand'
    WHEN utm.source_mkt = 'Performance' THEN 'Performance No Brand'
    WHEN (sd.last_source = '' OR sd.last_source IS NULL)
         AND sd.last_medium = 'direct'
      THEN 'Direct'
    WHEN utm.source_mkt IS NULL THEN 'Others'
    ELSE utm.source_mkt
  END AS mkt_source,

  /* ──────────── MKT SUBTEAM ──────────── */
  CASE
    WHEN utm.source_mkt = 'Performance'
         AND sd.last_source = 'google'
         AND POSITION('max-perf' IN sd.last_campaign) > 0
      THEN 'Google pMax'
    WHEN utm.source_mkt = 'Performance'
         AND sd.last_source IN ('google','bing')
         AND POSITION(sub_cam.utm_campaign IN sd.last_campaign) > 0
      THEN sub_cam.subteam
    WHEN utm.source_mkt = 'Product Marketing'
         AND POSITION(sub_cam.utm_campaign IN sd.last_campaign) > 0
      THEN sub_cam.subteam
    WHEN sd.last_source = 'chatgpt.com'
         AND (sd.last_medium = '' OR sd.last_medium IS NULL)
      THEN 'AI'
    WHEN utm.utm_subteam IS NOT NULL THEN utm.utm_subteam
    WHEN EXISTS (
           SELECT 1
           FROM inputs_url u
           WHERE sd.domain_clean = u.landing_page_domain
             AND sd.path_clean   = u.landing_page_path
         )
      THEN (
        SELECT u.url_subteam
        FROM inputs_url u
        WHERE sd.domain_clean = u.landing_page_domain
          AND sd.path_clean   = u.landing_page_path
        LIMIT 1
      )
    WHEN EXISTS (
           SELECT 1
           FROM inputs_insti i
           WHERE sd.domain_clean = i.landing_page_domain
             AND sd.path_clean   = i.landing_page_path
         )
      THEN (
        SELECT i.insti_subteam
        FROM inputs_insti i
        WHERE sd.domain_clean = i.landing_page_domain
          AND sd.path_clean   = i.landing_page_path
        LIMIT 1
      )
    ELSE mkt_source
  END AS mkt_subteam

FROM source_data sd
LEFT JOIN utm     ON sd.last_source = utm.utm_source   AND sd.last_medium = utm.utm_medium
LEFT JOIN sub_cam ON sd.last_source = sub_cam.utm_source AND sd.last_medium = sub_cam.utm_medium