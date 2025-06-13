-- Optimized ordering of pageviews with session-level count
WITH all_pageviews AS (
    SELECT
        event_timestamp,
        event_date,
        user_pseudo_id,
        unique_session,
        source_ga4_classification,
        original_user_country,
        env_pagegroup,
        landing_page,
        last_source,
        last_medium,
        last_campaign,
        utm_ad_id,
        -- sequential rank per session by timestamp
        ROW_NUMBER() OVER (
            PARTITION BY unique_session
            ORDER BY event_timestamp ASC
        ) AS rn,
        -- total pageviews per session 
        COUNT(*) OVER (
            PARTITION BY unique_session
        ) AS pageviews_per_session
    FROM {{ ref('ga4__mod_pv_info') }}
    WHERE unique_session IS NOT NULL
)

SELECT *
FROM all_pageviews