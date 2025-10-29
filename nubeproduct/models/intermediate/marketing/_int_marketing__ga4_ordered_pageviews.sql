WITH ranked AS (
    SELECT
        mpv.event_timestamp,
        mpv.event_date,
        mpv.year_month_day_code,
        mpv.user_pseudo_id,
        mpv.unique_session,
        mpv.source_ga4_classification,
        mpv.original_user_country,
        mpv.env_pagegroup,
        mpv.landing_page,
        mpv.landing_page_domain,
        mpv.landing_page_path,
        mpv.last_source,
        mpv.last_medium,
        mpv.last_campaign,
        mpv.utm_ad_id,
        mpv.utm_content,
        mpv.utm_term,
        ROW_NUMBER() OVER (
            PARTITION BY mpv.unique_session
            ORDER BY mpv.event_timestamp
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY mpv.unique_session
        ) AS pageviews_per_session
    FROM {{ ref('marketing__acquisition__ga4_mod_pv_info__event') }} mpv
)

SELECT
    event_timestamp,
    event_date,
    year_month_day_code,
    user_pseudo_id,
    unique_session,
    source_ga4_classification,
    original_user_country,
    env_pagegroup,
    landing_page,
    landing_page_domain,
    landing_page_path,
    last_source,
    last_medium,
    last_campaign,
    utm_ad_id,
    utm_content,
    utm_term,
    pageviews_per_session,
    CASE
      WHEN lower(landing_page) LIKE '%login%' THEN 'login'
      ELSE 'other'
    END AS landing_page_type
FROM ranked
WHERE rn = 1



