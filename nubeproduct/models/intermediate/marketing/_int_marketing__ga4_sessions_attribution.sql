WITH base AS (

  SELECT
    src.*,
    CAST(date_format(src.date, 'yyyyMMdd') AS int) AS year_month_day_code
  FROM {{ ref('marketing_ga4_sessions_aggregated') }} src

),

joined AS (

  SELECT
  b.date,
  b.session_id,
  b.user_pseudo_id,
  b.landing_page_domain,
  b.landing_page_path,
  b.last_source,
  b.last_medium,
  b.last_campaign,
  b.utm_ad_id,
  b.only_login_session,
  b.source_ga4_classification,
  b.env,
  b.trial,
  b.payment,
  b.session_duration_minutes,
  b.pageviews_per_session,
  b.first_event_device,
  b.last_event_device,
  b.original_user_country,
  b.user_type,
  b.engage,
  b.year_month_day_code,

  matches.team AS matched_team,
  matches.subteam AS matched_subteam

FROM base b
LEFT JOIN {{ ref('_int_marketing__ga4_url_matches') }} matches
  ON POSITION(matches.landing_page_path IN b.landing_page_path) > 0
 AND POSITION(matches.landing_page_domain IN b.landing_page_domain) > 0

)

SELECT
  *,
  
  /* ───────────────  MKT SOURCE  ─────────────── */
  CASE
    WHEN last_source = 'direct'
         AND last_medium IS NULL
         AND last_campaign IS NULL
         AND (
              POSITION('partners.tiendanube.com' IN landing_page_domain) > 0 OR
              POSITION('partners.nuvemshop.com.br' IN landing_page_domain) > 0
         )
      THEN 'Partners'

    WHEN last_source IN ('yahoo', 'google', 'bing')
         AND last_medium = 'organic'
         AND matched_team IS NOT NULL
      THEN matched_team

    WHEN POSITION('/partners/' IN landing_page_path) > 0
      THEN 'Affiliates'

    WHEN last_source IN ('chatgpt.com', 'claude.ai', 'copilot.microsoft.com')
         AND matched_team IS NOT NULL
      THEN matched_team

    WHEN utms.source_mkt = 'Communications'
      THEN 'Communications'

    WHEN utms.source_mkt = 'Performance'
         AND last_source IN ('google', 'bing')
         AND POSITION('-brand' IN last_campaign) > 0
      THEN 'Performance Brand'

    WHEN utms.source_mkt = 'Performance'
      THEN 'Performance No Brand'

    WHEN (last_source = '' OR last_source IS NULL)
         AND last_medium = 'direct'
         AND matched_team IS NOT NULL
      THEN matched_team

    WHEN (last_source = '' OR last_source IS NULL)
         AND last_medium = 'direct'
      THEN 'Direct'

    WHEN utms.source_mkt IS NULL
         AND last_medium = 'direct'
      THEN 'Direct'

    WHEN utms.source_mkt IS NULL
         AND last_source = 'youtube'
         AND last_medium = 'social'
         AND matched_team IS NOT NULL
      THEN matched_team

    WHEN (last_source = '' OR last_source IS NULL)
         AND (last_medium = '' OR last_medium IS NULL)
      THEN 'Others'

    WHEN utms.source_mkt IS NULL
      THEN 'Others'

    ELSE utms.source_mkt
  END AS mkt_source,

  /* ───────────────  MKT SUBTEAM  ─────────────── */
  CASE
    WHEN utms.source_mkt = 'Performance'
         AND last_source = 'google'
         AND POSITION('max-perf' IN last_campaign) > 0
      THEN 'Google pMax'

    WHEN utms.source_mkt = 'Performance'
         AND last_source IN ('google', 'bing')
         AND POSITION(sub.utm_campaign IN last_campaign) > 0
      THEN sub.subteam

    WHEN utms.source_mkt = 'Product Marketing'
         AND POSITION(sub.utm_campaign IN last_campaign) > 0
      THEN sub.subteam

    WHEN last_source = 'chatgpt.com'
         AND (last_medium = '' OR last_medium IS NULL)
      THEN 'AI'

    WHEN matched_subteam IS NOT NULL
      THEN matched_subteam

    WHEN utms.subteam IS NOT NULL
      THEN utms.subteam

    ELSE mkt_source
  END AS mkt_subteam

FROM joined
LEFT JOIN {{ ref('marketing_inputs_attribution__utm') }} utms
  ON last_source = utms.source AND last_medium = utms.medium
LEFT JOIN {{ ref('marketing_inputs_attribution__subteam') }} sub
  ON last_source = sub.utm_source AND last_medium = sub.utm_medium
