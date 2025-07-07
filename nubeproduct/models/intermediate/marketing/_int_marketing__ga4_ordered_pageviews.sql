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
        last_source,
        last_medium,
        last_campaign,
        pageviews_per_session,

        regexp_extract(landing_page,'id_([0-9]+)&utm',1) AS utm_ad_id,
        CASE WHEN instr(lower(landing_page),'login')>0
             THEN 'login' ELSE 'other' END             AS landing_page_type
    FROM ranked
    WHERE rn = 1
)

SELECT * FROM first_pv



