WITH ranked AS (
    SELECT
        mpv.*,
        ROW_NUMBER() OVER (
            PARTITION BY unique_session
            ORDER BY event_timestamp
        ) AS rn,
        COUNT(*) OVER (
            PARTITION BY unique_session
        ) AS pageviews_per_session
    FROM {{ ref('ga4__mod_pv_info') }} mpv
),

first_pv AS (
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
)

SELECT * 
FROM first_pv



