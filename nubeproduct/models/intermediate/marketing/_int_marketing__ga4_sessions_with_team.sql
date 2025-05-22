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
)

SELECT
    b.*,

    -- TEAM
    CASE
        -- 1. Partners
        WHEN (ls IN ('direct', 'organic', '') AND (
            lower(landing_page) LIKE '%partners.tiendanube.com%' OR lower(landing_page) LIKE '%partners.nuvemshop.com.br%')
        ) THEN 'Partners'

        -- 2. Others (null source y medium)
        WHEN (ls = '' AND lm = '') THEN 'Others'

        -- 3. Direct (source/medium combinaciones)
        WHEN (
            (ls = '' AND lm = 'direct') OR (ls = 'direct' AND lm = '') OR (ls = 'direct' AND lm = 'direct')
        ) THEN COALESCE(
            (
                SELECT team FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            'Direct'
        )

        -- 4. Organic (source/medium combinaciones)
        WHEN (
            (ls = '' AND lm = 'organic') OR (ls = 'organic' AND lm = '') OR (ls = 'organic' AND lm = 'organic')
        ) THEN COALESCE(
            (
                SELECT team FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            'Organic'
        )

        -- 5. Buscadores (source buscador + medium organic)
        WHEN (ls IN ('google', 'bing', 'yahoo') AND lm = 'organic') THEN COALESCE(
            (
                SELECT team FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            'Organic'
        )

        -- 6. AI
        WHEN (ls IN ('chatgpt.com', 'claude.ai', 'copilot.microsoft.com')) THEN COALESCE(
            (
                SELECT team FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'SUBTEAM_MKT'
                  AND utm_source = ls AND utm_medium = lm AND utm_campaign = lc
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'UTM'
                  AND utm_source = ls AND utm_medium = lm
                LIMIT 1
            ),
            'Organic'
        )

        -- 7. Catch-all: Busca primero URL, referrer, luego utm/subteam
        ELSE COALESCE(
            (
                SELECT team FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'SUBTEAM_MKT'
                  AND utm_source = ls AND utm_medium = lm AND utm_campaign = lc
                LIMIT 1
            ),
            (
                SELECT team FROM inputs
                WHERE input_type = 'UTM'
                  AND utm_source = ls AND utm_medium = lm
                LIMIT 1
            ),
            'Others'
        )
    END AS team,

    -- SUBTEAM: idéntico pero trayendo el campo subteam
    CASE
        WHEN (ls IN ('direct', 'organic', '') AND (
            lower(landing_page) LIKE '%partners.tiendanube.com%' OR lower(landing_page) LIKE '%partners.nuvemshop.com.br%')
        ) THEN 'Partners'

        WHEN (ls = '' AND lm = '') THEN 'Others'

        WHEN (
            (ls = '' AND lm = 'direct') OR (ls = 'direct' AND lm = '') OR (ls = 'direct' AND lm = 'direct')
        ) THEN COALESCE(
            (
                SELECT subteam FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            'Direct'
        )

        WHEN (
            (ls = '' AND lm = 'organic') OR (ls = 'organic' AND lm = '') OR (ls = 'organic' AND lm = 'organic')
        ) THEN COALESCE(
            (
                SELECT subteam FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            'Organic'
        )

        WHEN (ls IN ('google', 'bing', 'yahoo') AND lm = 'organic') THEN COALESCE(
            (
                SELECT subteam FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            'Organic'
        )

        WHEN (ls IN ('chatgpt.com', 'claude.ai', 'copilot.microsoft.com')) THEN COALESCE(
            (
                SELECT subteam FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'SUBTEAM_MKT'
                  AND utm_source = ls AND utm_medium = lm AND utm_campaign = lc
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'UTM'
                  AND utm_source = ls AND utm_medium = lm
                LIMIT 1
            ),
            'Ai'
        )

        ELSE COALESCE(
            (
                SELECT subteam FROM inputs
                WHERE input_type IN ('URL', 'INSTI')
                  AND lower(b.landing_page) LIKE lower(landing_page_path)
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'REFERRER'
                  AND lower(b.landing_page) LIKE lower(referrer)
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'SUBTEAM_MKT'
                  AND utm_source = ls AND utm_medium = lm AND utm_campaign = lc
                LIMIT 1
            ),
            (
                SELECT subteam FROM inputs
                WHERE input_type = 'UTM'
                  AND utm_source = ls AND utm_medium = lm
                LIMIT 1
            ),
            'Others'
        )
    END AS subteam

FROM base b
