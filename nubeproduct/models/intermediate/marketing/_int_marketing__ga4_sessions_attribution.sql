WITH
-- 1) Base sessions table
src AS (
  SELECT *
  FROM {{ ref('_int_marketing__ga4_sessions_aggregated') }}
),

-- 2) UTM mapping inputs
utms AS (
  SELECT
    source,
    medium,
    source_mkt,
    subteam
  FROM {{ ref('marketing_inputs_attribution__utm') }}
),

-- 3) Campaign‐specific subteam inputs
sub AS (
  SELECT
    utm_source   AS source,
    utm_medium   AS medium,
    utm_campaign AS campaign,
    subteam
  FROM {{ ref('marketing_inputs_attribution__subteam') }}
),

-- 4) URL mapping inputs
urls AS (
  SELECT
    landing_page_path,
    landing_page_domain,
    team,
    subteam
  FROM {{ ref('marketing_inputs_attribution__url') }}
),

-- 5) “Insti” mapping inputs
insti AS (
  SELECT
    landing_page_path,
    landing_page_domain,
    team,
    subteam
  FROM {{ ref('marketing_inputs_attribution__insti') }}
)

SELECT
  -- A) preserve all original session fields
  src.*,

  /* === mkt_source: done as in mkt_attribution === */
  CASE
    -- 1) Partners: direct + partners domains + no source/medium/campaign
    WHEN src.last_source   = 'direct'
         AND src.last_medium   IS NULL
         AND src.last_campaign IS NULL
         AND (
           instr(src.landing_page, 'partners.tiendanube.com')    > 0
        OR instr(src.landing_page, 'partners.nuvemshop.com.br') > 0
         )
      THEN 'Partners'

    -- 2) Organic → URL team
    WHEN src.last_source IN ('yahoo','google','bing')
         AND src.last_medium = 'organic'
         AND instr(src.landing_page, urls.landing_page_path)   > 0
         AND instr(src.landing_page, urls.landing_page_domain) > 0
      THEN urls.team

    -- 3) Affiliates via “/partners/” in path
    WHEN instr(src.landing_page, '/partners/') > 0
      THEN 'Affiliates'

    -- 4) Organic → insti team
    WHEN src.last_source IN ('yahoo','google','bing')
         AND src.last_medium = 'organic'
         AND instr(src.landing_page, insti.landing_page_path)   > 0
         AND instr(src.landing_page, insti.landing_page_domain) > 0
      THEN insti.team

    -- 5) AI channels → URL team
    WHEN src.last_source IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
         AND instr(src.landing_page, urls.landing_page_path)   > 0
         AND instr(src.landing_page, urls.landing_page_domain) > 0
      THEN urls.team

    -- 6) AI channels → insti team
    WHEN src.last_source IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
         AND instr(src.landing_page, insti.landing_page_path)   > 0
         AND instr(src.landing_page, insti.landing_page_domain) > 0
      THEN insti.team

    -- 7) Communications (explicit UTM category)
    WHEN utms.source_mkt = 'Communications'
      THEN 'Communications'

    -- 8) Performance Brand
    WHEN utms.source_mkt = 'Performance'
         AND src.last_source IN ('google','bing')
         AND instr(src.last_campaign, '-brand') > 0
      THEN 'Performance Brand'

    -- 9) Performance No Brand
    WHEN utms.source_mkt = 'Performance'
      THEN 'Performance No Brand'

    -- 10) Blank source + direct + URL team
    WHEN (src.last_source = '' OR src.last_source IS NULL)
         AND src.last_medium = 'direct'
         AND instr(src.landing_page, urls.landing_page_path)   > 0
         AND instr(src.landing_page, urls.landing_page_domain) > 0
      THEN urls.team

    -- 11) Blank source + direct → Direct
    WHEN (src.last_source = '' OR src.last_source IS NULL)
         AND src.last_medium = 'direct'
      THEN 'Direct'

    -- 12) UTM missing + direct/direct campaign + URL team
    WHEN utms.source_mkt IS NULL
         AND src.last_medium   = 'direct'
         AND src.last_campaign = 'direct'
         AND instr(src.landing_page, urls.landing_page_path)   > 0
         AND instr(src.landing_page, urls.landing_page_domain) > 0
      THEN urls.team

    -- 13) UTM missing + direct/direct campaign → Direct
    WHEN utms.source_mkt IS NULL
         AND src.last_medium   = 'direct'
         AND src.last_campaign = 'direct'
      THEN 'Direct'

    -- 14) UTM missing + medium direct → Direct
    WHEN utms.source_mkt IS NULL
         AND src.last_medium = 'direct'
      THEN 'Direct'

    -- 15) UTM missing + YouTube Social → URL team
    WHEN utms.source_mkt IS NULL
         AND src.last_source = 'youtube'
         AND src.last_medium = 'social'
         AND instr(src.landing_page, urls.landing_page_path)   > 0
         AND instr(src.landing_page, urls.landing_page_domain) > 0
      THEN urls.team

    -- 16) Blank source + blank medium → Others
    WHEN (src.last_source = '' OR src.last_source IS NULL)
         AND (src.last_medium = '' OR src.last_medium IS NULL)
      THEN 'Others'

    -- 17) UTM missing → Others
    WHEN utms.source_mkt IS NULL
      THEN 'Others'

    ELSE utms.source_mkt
  END AS mkt_source,

  /* === mkt_subteam: done as in mkt_attribution === */
  CASE
    -- 1) Google pMax
    WHEN utms.source_mkt = 'Performance'
         AND src.last_source = 'google'
         AND instr(src.last_campaign, 'max-perf') > 0
      THEN 'Google pMax'

    -- 2) Performance subteam by campaign
    WHEN utms.source_mkt = 'Performance'
         AND src.last_source IN ('google','bing')
         AND instr(src.last_campaign, sub.campaign) > 0
      THEN sub.subteam

    -- 3) Product Marketing subteam by campaign
    WHEN utms.source_mkt = 'Product Marketing'
         AND instr(src.last_campaign, sub.campaign) > 0
      THEN sub.subteam

    -- 4) AI pure
    WHEN src.last_source = 'chatgpt.com'
         AND (src.last_medium = '' OR src.last_medium IS NULL)
      THEN 'AI'

    -- 5) URL subteam
    WHEN instr(src.landing_page, urls.landing_page_path)   > 0
         AND instr(src.landing_page, urls.landing_page_domain) > 0
      THEN urls.subteam

    -- 6) Insti subteam
    WHEN instr(src.landing_page, insti.landing_page_path)   > 0
         AND instr(src.landing_page, insti.landing_page_domain) > 0
      THEN insti.subteam

    -- 7) Fallback to UTM subteam
    WHEN utms.subteam IS NOT NULL
      THEN utms.subteam

    -- 8) Last resort: use mkt_source as subteam
    ELSE mkt_source
  END AS mkt_subteam

FROM src
LEFT JOIN utms   ON src.last_source = utms.source   AND src.last_medium = utms.medium
LEFT JOIN sub    ON src.last_source = sub.source    AND src.last_medium = sub.medium
LEFT JOIN urls   ON instr(src.landing_page, urls.landing_page_path)   > 0
                AND instr(src.landing_page, urls.landing_page_domain) > 0
LEFT JOIN insti  ON instr(src.landing_page, insti.landing_page_path)   > 0
                AND instr(src.landing_page, insti.landing_page_domain) > 0
