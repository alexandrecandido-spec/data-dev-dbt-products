WITH ordered_pageviews AS (
    SELECT *
    FROM {{ ref('_int_marketing__ga4_ordered_pageviews') }}
),

login_sessions AS (
    SELECT unique_session, 1 AS login_in_session
    FROM (
        SELECT
            unique_session,
            ROW_NUMBER() OVER (
                PARTITION BY unique_session
                ORDER BY event_date ASC
            ) AS rn
        FROM {{ ref('ga4__event_info') }}
        WHERE event_type = 'login'
          AND unique_session IS NOT NULL
    ) t
    WHERE rn = 1
),

trials AS (
    SELECT
        t.unique_session,
        COUNT(*) AS trial
    FROM {{ ref('ga4__tp_info') }} t
    WHERE t.trial_timestamp IS NOT NULL
    GROUP BY t.unique_session
),

payments AS (
    SELECT
        t.unique_session,
        COUNT(*) AS payment
    FROM {{ ref('ga4__tp_info') }} t
    WHERE t.payment_timestamp IS NOT NULL
    GROUP BY t.unique_session
),

session_data AS (
    SELECT *
    FROM (
        SELECT 
            unique_session,
            engage,
            session_duration_minutes,
            ROW_NUMBER() OVER (
                PARTITION BY unique_session
                ORDER BY session_duration_minutes DESC NULLS LAST
            ) AS rn
        FROM {{ ref('ga4__session_info') }}
    ) t
    WHERE rn = 1
),

event_devices AS (
    SELECT *
    FROM (
        SELECT
            unique_session,
            FIRST_VALUE(event_device) OVER (
                PARTITION BY unique_session ORDER BY event_date ASC
            ) AS first_event_device,
            FIRST_VALUE(event_device) OVER (
                PARTITION BY unique_session ORDER BY event_date DESC
            ) AS last_event_device,
            ROW_NUMBER() OVER (
                PARTITION BY unique_session ORDER BY event_date ASC
            ) AS rn
        FROM {{ ref('ga4__event_info') }}
        WHERE unique_session IS NOT NULL
          AND event_device IS NOT NULL
    ) t
    WHERE rn = 1
),

first_visits AS (
    SELECT *
    FROM (
        SELECT
            user_pseudo_id,
            first_visit_date,
            ROW_NUMBER() OVER (
                PARTITION BY user_pseudo_id
                ORDER BY first_visit_date ASC
            ) AS rn
        FROM {{ source('int_ga4', 'first_visit') }}
    ) t
    WHERE rn = 1
)

SELECT
    op.event_date                             AS date,
    op.source_ga4_classification,
    op.original_user_country,
    op.env_pagegroup                          AS env,
    op.landing_page,
    op.landing_page_domain,
    op.landing_page_path,
    op.landing_page_type,
    op.last_source,
    op.last_medium,
    op.last_campaign,
    op.utm_ad_id,
    op.utm_content,
    op.utm_term,
    op.user_pseudo_id,
    op.unique_session,
    ed.first_event_device,
    ed.last_event_device,
    COALESCE(ls.login_in_session, 0)           AS login_in_session,
    COALESCE(t.trial,   0)                     AS trial,
    COALESCE(p.payment, 0)                     AS payment,
    CASE
      WHEN (COALESCE(ls.login_in_session, 0) = 1
            OR COALESCE(op.landing_page_type, '') = 'login')
           AND COALESCE(t.trial, 0) = 0
           AND COALESCE(p.payment, 0) = 0
      THEN 1 ELSE 0
    END                                       AS only_login_session,
    sd.engage,
    sd.session_duration_minutes,
    op.pageviews_per_session,
    CASE
        WHEN fv.first_visit_date = op.event_date THEN 'New'
        ELSE 'Returning'
    END                                       AS user_type
FROM ordered_pageviews op
LEFT JOIN login_sessions ls  ON op.unique_session = ls.unique_session
LEFT JOIN trials         t   ON op.unique_session = t.unique_session
LEFT JOIN payments       p   ON op.unique_session = p.unique_session
LEFT JOIN session_data   sd  ON op.unique_session = sd.unique_session
LEFT JOIN first_visits   fv  ON op.user_pseudo_id  = fv.user_pseudo_id
LEFT JOIN event_devices  ed  ON op.unique_session = ed.unique_session