WITH login_sessions AS (
    SELECT DISTINCT unique_session, 1 AS login_in_session
    FROM {{ ref('ga4__event_info') }}
    WHERE event_name LIKE '%login%' AND unique_session IS NOT NULL
),

trials AS (
    SELECT unique_session, 1 AS trial
    FROM {{ ref('ga4__tp_info') }}
    WHERE trial_timestamp IS NOT NULL
),

payments AS (
    SELECT unique_session, 1 AS payment
    FROM {{ ref('ga4__tp_info') }}
    WHERE payment_timestamp IS NOT NULL
),

pageviews_per_session AS (
    SELECT unique_session, COUNT(*) AS pageviews_per_session
    FROM {{ ref('ga4__mod_pv_info') }}
    GROUP BY unique_session
),

classified_pageview AS (
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY unique_session ORDER BY event_timestamp ASC) AS rn
        FROM {{ ref('ga4__mod_pv_info') }}
    ) filtered
    WHERE rn = 1
),

session_data AS (
    SELECT *
    FROM {{ ref('ga4__session_info') }}
),

first_visits AS (
    SELECT *
    FROM {{ ref('_int_marketing__ga4_first_visit') }}
)

SELECT 
    cp.event_date AS date,
    cp.source_ga4_classification,
    cp.original_user_country,
    cp.env_pagegroup AS env,
    cp.landing_page,
    cp.event_source,
    cp.event_medium,
    cp.user_pseudo_id,
    cp.unique_session,
    
    COALESCE(ls.login_in_session, 0) AS login_in_session,
    COALESCE(t.trial, 0) AS trial,
    COALESCE(p.payment, 0) AS payment,

    CASE WHEN cp.landing_page LIKE '%login%' THEN 1 ELSE 0 END AS landing_is_login,

    CASE 
        WHEN (COALESCE(ls.login_in_session, 0) = 1 OR cp.landing_page LIKE '%login%')
             AND COALESCE(t.trial, 0) = 0 
             AND COALESCE(p.payment, 0) = 0
        THEN 1 ELSE 0
    END AS only_login_session,

    s.engage,
    s.session_duration_minutes,
    pps.pageviews_per_session,

    CASE
        WHEN fv.first_visit_date = cp.event_date THEN 'New'
        WHEN fv.first_visit_date < cp.event_date THEN 'Returning'
        ELSE 'Unknown'
    END AS user_type

FROM classified_pageview cp
LEFT JOIN login_sessions ls ON cp.unique_session = ls.unique_session
LEFT JOIN trials t ON cp.unique_session = t.unique_session
LEFT JOIN payments p ON cp.unique_session = p.unique_session
LEFT JOIN session_data s ON cp.unique_session = s.unique_session
LEFT JOIN pageviews_per_session pps ON cp.unique_session = pps.unique_session
LEFT JOIN first_visits fv ON cp.user_pseudo_id = fv.user_pseudo_id
