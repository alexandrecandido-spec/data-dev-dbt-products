SELECT
  src.*,
 CAST(date_format(src.date,'yyyyMMdd') AS int) AS year_month_day_code,

  /* ───────────────  MKT SOURCE  ─────────────── */
  CASE
      WHEN src.last_source = 'direct'
           AND src.last_medium IS NULL
           AND src.last_campaign IS NULL
           AND (
                instr(src.landing_page,'partners.tiendanube.com')  > 0 OR
                instr(src.landing_page,'partners.nuvemshop.com.br')> 0
           )
        THEN 'Partners'

      WHEN src.last_source IN ('yahoo','google','bing')
           AND src.last_medium = 'organic'
           AND instr(src.landing_page, urls.landing_page_path)   > 0
           AND instr(src.landing_page, urls.landing_page_domain) > 0
        THEN urls.team

      WHEN instr(src.landing_page,'/partners/') > 0
        THEN 'Affiliates'

      WHEN src.last_source IN ('yahoo','google','bing')
           AND src.last_medium = 'organic'
           AND instr(src.landing_page, insti.landing_page_path)   > 0
           AND instr(src.landing_page, insti.landing_page_domain) > 0
        THEN insti.team

      WHEN src.last_source IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
           AND instr(src.landing_page, urls.landing_page_path)   > 0
           AND instr(src.landing_page, urls.landing_page_domain) > 0
        THEN urls.team

      WHEN src.last_source IN ('chatgpt.com','claude.ai','copilot.microsoft.com')
           AND instr(src.landing_page, insti.landing_page_path)   > 0
           AND instr(src.landing_page, insti.landing_page_domain) > 0
        THEN insti.team

      WHEN utms.source_mkt = 'Communications'
        THEN 'Communications'

      WHEN utms.source_mkt = 'Performance'
           AND src.last_source IN ('google','bing')
           AND instr(src.last_campaign,'-brand') > 0
        THEN 'Performance Brand'

      WHEN utms.source_mkt = 'Performance'
        THEN 'Performance No Brand'

      WHEN (src.last_source = '' OR src.last_source IS NULL)
           AND src.last_medium = 'direct'
           AND instr(src.landing_page, urls.landing_page_path)   > 0
           AND instr(src.landing_page, urls.landing_page_domain) > 0
        THEN urls.team

      WHEN (src.last_source = '' OR src.last_source IS NULL)
           AND src.last_medium = 'direct'
        THEN 'Direct'

      WHEN utms.source_mkt IS NULL
           AND src.last_medium = 'direct'
        THEN 'Direct'

      WHEN utms.source_mkt IS NULL
           AND src.last_source = 'youtube'
           AND src.last_medium = 'social'
           AND instr(src.landing_page, urls.landing_page_path)   > 0
           AND instr(src.landing_page, urls.landing_page_domain) > 0
        THEN urls.team

      WHEN (src.last_source = '' OR src.last_source IS NULL)
           AND (src.last_medium = '' OR src.last_medium IS NULL)
        THEN 'Others'

      WHEN utms.source_mkt IS NULL
        THEN 'Others'

      ELSE utms.source_mkt
  END AS mkt_source,

  /* ───────────────  MKT SUBTEAM  ─────────────── */
  CASE
      WHEN utms.source_mkt = 'Performance'
           AND src.last_source = 'google'
           AND instr(src.last_campaign,'max-perf') > 0
        THEN 'Google pMax'

      WHEN utms.source_mkt = 'Performance'
           AND src.last_source IN ('google','bing')
           AND instr(src.last_campaign, sub.utm_campaign) > 0
        THEN sub.subteam

      WHEN utms.source_mkt = 'Product Marketing'
           AND instr(src.last_campaign, sub.utm_campaign) > 0
        THEN sub.subteam

      WHEN src.last_source = 'chatgpt.com'
           AND (src.last_medium = '' OR src.last_medium IS NULL)
        THEN 'AI'

      WHEN instr(src.landing_page, urls.landing_page_path)   > 0
           AND instr(src.landing_page, urls.landing_page_domain) > 0
        THEN urls.subteam

      WHEN instr(src.landing_page, insti.landing_page_path)   > 0
           AND instr(src.landing_page, insti.landing_page_domain) > 0
        THEN insti.subteam

      WHEN utms.subteam IS NOT NULL
        THEN utms.subteam

      ELSE mkt_source
  END AS mkt_subteam


FROM {{ ref('marketing_ga4_sessions_aggregated') }} src

/* ---------- INPUT JOINS ---------- */
LEFT JOIN {{ ref('marketing_inputs_attribution__utm') }} utms
  ON  src.last_source = utms.source          
  AND src.last_medium = utms.medium

LEFT JOIN {{ ref('marketing_inputs_attribution__subteam') }} sub
  ON  src.last_source = sub.utm_source
  AND src.last_medium = sub.utm_medium

LEFT JOIN {{ ref('marketing_inputs_attribution__url') }} urls
  ON instr(src.landing_page, urls.landing_page_path)   > 0
  AND instr(src.landing_page, urls.landing_page_domain) > 0

LEFT JOIN {{ ref('marketing_inputs_attribution__insti') }} insti
  ON instr(src.landing_page, insti.landing_page_path)   > 0
  AND instr(src.landing_page, insti.landing_page_domain) > 0

