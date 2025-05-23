WITH base AS (
    SELECT
        *,
        COALESCE(last_source, '') AS ls,
        COALESCE(last_medium, '') AS lm,
        COALESCE(last_campaign, '') AS lc
    FROM {{ ref('_int_marketing__ga4_sessions_with_dimensions') }}
),

inputs AS (
    SELECT *
    FROM {{ ref('inputs_marketing_attribution') }}
    WHERE state = 'open'
),

-- Primer clasificación por reglas de negocio
classified AS (
    SELECT
        b.*,
        CASE
            WHEN (ls IN ('direct', 'organic', '') AND (
                lower(landing_page) LIKE '%partners.tiendanube.com%' OR lower(landing_page) LIKE '%partners.nuvemshop.com.br%'
            )) THEN 'Partners'
            WHEN (ls = '' AND lm = '') THEN 'Others'
            WHEN ((ls = '' AND lm = 'direct') OR (ls = 'direct' AND lm = '') OR (ls = 'direct' AND lm = 'direct')) THEN 'Direct'
            WHEN ((ls = '' AND lm = 'organic') OR (ls = 'organic' AND lm = '') OR (ls = 'organic' AND lm = 'organic')) THEN 'Organic'
            WHEN (ls IN ('google', 'bing', 'yahoo') AND lm = 'organic') THEN 'Organic'
            WHEN (ls IN ('chatgpt.com', 'claude.ai', 'copilot.microsoft.com')) THEN 'Ai'
            ELSE NULL
        END AS pre_team,
        CASE
            WHEN (ls IN ('direct', 'organic', '') AND (
                lower(landing_page) LIKE '%partners.tiendanube.com%' OR lower(landing_page) LIKE '%partners.nuvemshop.com.br%'
            )) THEN 'Partners'
            WHEN (ls = '' AND lm = '') THEN 'Others'
            WHEN ((ls = '' AND lm = 'direct') OR (ls = 'direct' AND lm = '') OR (ls = 'direct' AND lm = 'direct')) THEN 'Direct'
            WHEN ((ls = '' AND lm = 'organic') OR (ls = 'organic' AND lm = '') OR (ls = 'organic' AND lm = 'organic')) THEN 'Organic'
            WHEN (ls IN ('google', 'bing', 'yahoo') AND lm = 'organic') THEN 'Organic'
            WHEN (ls IN ('chatgpt.com', 'claude.ai', 'copilot.microsoft.com')) THEN 'Ai'
            ELSE NULL
        END AS pre_subteam
    FROM base b
),

-- Catch-all: solo para los que quedaron sin clasificar
match_inputs AS (
    SELECT
        c.unique_session,
        i.team,
        i.subteam,
        ROW_NUMBER() OVER (PARTITION BY c.unique_session
            ORDER BY
                CASE
                    WHEN i.input_type IN ('URL', 'INSTI') AND lower(c.landing_page) LIKE lower(i.landing_page_path) THEN 1
                    WHEN i.input_type = 'REFERRER' AND lower(c.landing_page) LIKE lower(i.referrer) THEN 2
                    WHEN i.input_type = 'SUBTEAM_MKT' AND i.utm_source = c.ls AND i.utm_medium = c.lm AND i.utm_campaign = c.lc THEN 3
                    WHEN i.input_type = 'UTM' AND i.utm_source = c.ls AND i.utm_medium = c.lm THEN 4
                    ELSE 5
                END
        ) AS rn
    FROM classified c
    LEFT JOIN inputs i
      ON (
            (i.input_type IN ('URL', 'INSTI') AND lower(c.landing_page) LIKE lower(i.landing_page_path))
         OR (i.input_type = 'REFERRER' AND lower(c.landing_page) LIKE lower(i.referrer))
         OR (i.input_type = 'SUBTEAM_MKT' AND i.utm_source = c.ls AND i.utm_medium = c.lm AND i.utm_campaign = c.lc)
         OR (i.input_type = 'UTM' AND i.utm_source = c.ls AND i.utm_medium = c.lm)
      )
    WHERE c.pre_team IS NULL -- solo para los no clasificados
),
best_match AS (
    SELECT unique_session, team, subteam
    FROM match_inputs
    WHERE rn = 1
)

SELECT
    c.*,
    COALESCE(NULLIF(c.pre_team, ''), bm.team, 'Others') AS team,
    COALESCE(NULLIF(c.pre_subteam, ''), bm.subteam, 'Others') AS subteam
FROM classified c
LEFT JOIN best_match bm
  ON c.unique_session = bm.unique_session

