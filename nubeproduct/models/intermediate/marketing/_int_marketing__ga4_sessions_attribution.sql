WITH base AS (          -- 1. Limpieza de dominio y path
    SELECT
        agg.*,
        REGEXP_REPLACE(agg.landing_page_domain,
                       '^(?:https?://)?(?:www\\.)?', '')  AS domain_clean,
        agg.landing_page_path                            AS path_clean
    FROM {{ ref('marketing_ga4_sessions_aggregated') }} agg
),

/* -------------------------------- 2. Mejor coincidencia de URL -------------------------------- */
url_enriched AS (
    SELECT
        b.*,
        u.team    AS url_team,
        u.subteam AS url_subteam
    FROM base b
LEFT JOIN LATERAL (      
    SELECT team , subteam
    FROM {{ ref('marketing_inputs_attribution__url') }} u
    WHERE  u.landing_page_domain = b.domain_clean
      AND POSITION(u.landing_page_path IN b.path_clean) > 0
    ORDER BY LENGTH(u.landing_page_path) DESC
    LIMIT 1
) u ON TRUE
),

/* ---------------------------- 3. Mejor coincidencia insti ----------------------------- */
insti_enriched AS (
    SELECT
        u.*,
        i.team    AS insti_team,
        i.subteam AS insti_subteam
    FROM url_enriched u
LEFT JOIN LATERAL (
    SELECT team , subteam
    FROM {{ ref('marketing_inputs_attribution__insti') }} i
    WHERE  i.landing_page_domain = u.domain_clean
      AND POSITION(i.landing_page_path IN u.path_clean) > 0
    ORDER BY LENGTH(i.landing_page_path) DESC
    LIMIT 1
) i ON TRUE
),

/* ------------------------------------ 4. UTM & sub-campaign ----------------------------------- */
utm_enriched AS (
    SELECT
        i.*,
        u.source_mkt,
        u.subteam    AS utm_subteam
    FROM insti_enriched i
    LEFT JOIN LATERAL (
        SELECT source_mkt, subteam
        FROM {{ ref('marketing_inputs_attribution__utm') }} u
        WHERE u.source = i.last_source
          AND u.medium = i.last_medium
        LIMIT 1
    ) u ON TRUE
),

subcam_enriched AS (
    SELECT
        u.*,
        s.subteam      AS subteam_cam,
        s.utm_campaign AS utm_campaign_cam
    FROM utm_enriched u
    LEFT JOIN LATERAL (
        SELECT subteam, utm_campaign
        FROM {{ ref('marketing_inputs_attribution__subteam') }} s
        WHERE s.utm_source = u.last_source
          AND s.utm_medium = u.last_medium
        LIMIT 1
    ) s ON TRUE
)

/* ------------------------------------ 5. Reglas de negocio ------------------------------------ */
SELECT
    s.* EXCEPT(url_team , url_subteam , insti_team , insti_subteam ,
               source_mkt , utm_subteam , subteam_cam , utm_campaign_cam),

    /* ---- URL owner & content type ---- */
    COALESCE(s.url_team ,   s.insti_team   ) AS url_owner,
    COALESCE(s.url_subteam , s.insti_subteam) AS url_content_type,

    /* ------------------ MKT SOURCE ------------------ */
    CASE
        WHEN s.last_source = 'direct'
             AND s.last_medium IS NULL
             AND s.last_campaign IS NULL
             AND s.domain_clean IN ('partners.tiendanube.com',
                                     'partners.nuvemshop.com.br')
          THEN 'Partners'

        WHEN s.last_source IN ('yahoo','google','bing')
             AND s.last_medium = 'organic'
               AND (s.url_team IS NOT NULL OR s.insti_team IS NOT NULL)
    THEN COALESCE(s.url_team , s.insti_team)

        WHEN s.source_mkt = 'Communications' THEN 'Communications'

        WHEN s.source_mkt = 'Performance'
             AND s.last_source IN ('google','bing')
             AND POSITION('-brand' IN s.last_campaign) > 0
          THEN 'Performance Brand'

        WHEN s.source_mkt = 'Performance'            THEN 'Performance No Brand'
        WHEN (s.last_source = '' OR s.last_source IS NULL)
             AND s.last_medium = 'direct'            THEN 'Direct'
        WHEN s.source_mkt IS NULL                    THEN 'Others'
        ELSE s.source_mkt
    END AS mkt_source,

    /* ------------------ MKT SUBTEAM ------------------ */
    CASE
        WHEN s.source_mkt = 'Performance'
             AND s.last_source = 'google'
             AND POSITION('max-perf' IN s.last_campaign) > 0
          THEN 'Google pMax'

        WHEN s.source_mkt = 'Performance'
             AND s.last_source IN ('google','bing')
             AND POSITION(s.utm_campaign_cam IN s.last_campaign) > 0
          THEN s.subteam_cam

        WHEN s.source_mkt = 'Product Marketing'
             AND POSITION(s.utm_campaign_cam IN s.last_campaign) > 0
          THEN s.subteam_cam

        WHEN s.last_source = 'chatgpt.com'
             AND (s.last_medium = '' OR s.last_medium IS NULL)
          THEN 'AI'

        WHEN s.utm_subteam   IS NOT NULL               THEN s.utm_subteam
        WHEN s.url_subteam   IS NOT NULL               THEN s.url_subteam
        WHEN s.insti_subteam IS NOT NULL               THEN s.insti_subteam

        ELSE mkt_source
    END AS mkt_subteam

FROM subcam_enriched s

