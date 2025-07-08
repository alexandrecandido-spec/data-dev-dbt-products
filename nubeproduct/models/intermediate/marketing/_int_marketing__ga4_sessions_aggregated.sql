WITH prepared AS (
    SELECT
        src.*,
        CASE WHEN engage = 1 THEN 'Engaged' ELSE 'Bounced' END AS session_status
    FROM {{ ref('_int_marketing__ga4_sessions_classified') }} AS src
),

aggregated AS (
    SELECT
        date,
        year_month_day_code,
        source_ga4_classification,
        original_user_country,
        classified_country,
        env,
        landing_page,
        landing_page_domain,
        landing_page_path,
        last_source,
        last_medium,
        last_campaign,
        utm_ad_id,
        utm_content,
        utm_term,
        first_event_device,
        last_event_device,
        only_login_session,
        login_in_session,
        landing_page_type,
        user_type,
        session_status,

        COUNT(DISTINCT user_pseudo_id)                           AS distinct_user_count,
        COUNT(DISTINCT unique_session)                           AS distinct_session_count,
        SUM(trial)                                               AS total_trials,
        SUM(payment)                                             AS total_payments,
        SUM(CASE WHEN session_status = 'Engaged' THEN 1 END)     AS total_engagements,
        AVG(session_duration_minutes)                            AS avg_session_duration,
        APPROX_PERCENTILE(session_duration_minutes, 0.5)         AS median_session_duration,
        AVG(pageviews_per_session)                               AS avg_pageviews_per_session,
        APPROX_PERCENTILE(pageviews_per_session, 0.5)            AS median_pageviews_per_session
    FROM prepared
    GROUP BY
        date,
        year_month_day_code,
        source_ga4_classification,
        original_user_country,
        classified_country,
        env,
        landing_page,
        landing_page_domain,
        landing_page_path,
        last_source,
        last_medium,
        last_campaign,
        utm_ad_id,
        utm_content,
        utm_term,
        first_event_device,
        last_event_device,
        only_login_session,
        login_in_session,
        landing_page_type,
        user_type,
        session_status
)

SELECT * 
FROM aggregated
