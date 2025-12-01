WITH ordered_pageviews AS (
    SELECT *
    FROM {{ ref('_int_marketing__ga4_ordered_pageviews') }}
),

events_source AS (
    SELECT
        unique_session,
        event_date,
        event_device,
        sys_audit_updated_on,
        CASE 
            WHEN instr(lower(event_name),'login') > 0 THEN 'login' 
            ELSE 'other' 
        END AS event_type
    FROM {{ ref('marketing_event_info') }}
    WHERE unique_session IS NOT NULL
      AND event_date >= DATE '2024-01-01'
),

login_sessions AS (
    SELECT 
        unique_session, 
        1 AS login_in_session,
        MAX(sys_audit_updated_on) as sys_audit_updated_on
    FROM (
        SELECT
            unique_session,
            sys_audit_updated_on,
            ROW_NUMBER() OVER (
                PARTITION BY unique_session
                ORDER BY event_date ASC
            ) AS rn
        FROM events_source
        WHERE event_type = 'login'
    ) t
    WHERE rn = 1
    GROUP BY unique_session
),

trials_payments_source AS (
    SELECT
        unique_session,
        trial_timestamp,
        payment_timestamp,
        sys_audit_updated_on
    FROM {{ ref('marketing_tp_info') }}
    WHERE unique_session IS NOT NULL
      AND (trial_timestamp IS NOT NULL OR payment_timestamp IS NOT NULL)
      AND COALESCE(trial_date, payment_date) >= DATE '2024-01-01'
),

trials AS (
    SELECT
        unique_session,
        COUNT(*) AS trial,
        MAX(sys_audit_updated_on) as sys_audit_updated_on
    FROM trials_payments_source
    WHERE trial_timestamp IS NOT NULL
    GROUP BY unique_session
),

payments AS (
    SELECT
        unique_session,
        COUNT(*) AS payment,
        MAX(sys_audit_updated_on) as sys_audit_updated_on
    FROM trials_payments_source
    WHERE payment_timestamp IS NOT NULL
    GROUP BY unique_session
),

session_info_source AS (
    SELECT
        unique_session,
        engage,
        sys_audit_updated_on,
        CASE
            WHEN end_session_time >= start_session_time
            THEN ROUND((end_session_time - start_session_time) / 60000000.0, 2)
            ELSE NULL
        END AS session_duration_minutes_calc,
        CASE
            WHEN engage IS NOT NULL THEN engage
            WHEN end_session_time >= start_session_time
                 AND ROUND((end_session_time - start_session_time) / 60000000.0, 2) > 0
            THEN 1 ELSE 0
        END AS engage_calc
    FROM {{ ref('marketing_session_info') }}
    WHERE unique_session IS NOT NULL
      AND start_session_date >= DATE '2024-01-01'
),

session_data AS (
    SELECT *
    FROM (
        SELECT
            unique_session,
            engage_calc AS engage,
            session_duration_minutes_calc AS session_duration_minutes,
            sys_audit_updated_on,
            ROW_NUMBER() OVER (
                PARTITION BY unique_session
                ORDER BY session_duration_minutes_calc DESC NULLS LAST
            ) AS rn
        FROM session_info_source
    ) t
    WHERE rn = 1
),

event_devices AS (
    SELECT *
    FROM (
        SELECT
            unique_session,
            sys_audit_updated_on,
            FIRST_VALUE(event_device) OVER (
                PARTITION BY unique_session ORDER BY event_date ASC
            ) AS first_event_device,
            FIRST_VALUE(event_device) OVER (
                PARTITION BY unique_session ORDER BY event_date DESC
            ) AS last_event_device,
            ROW_NUMBER() OVER (
                PARTITION BY unique_session ORDER BY event_date ASC
            ) AS rn
        FROM events_source
        WHERE event_device IS NOT NULL
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
        FROM {{ ref('marketing_first_visit') }}
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
    END                                        AS only_login_session,
    sd.engage,
    sd.session_duration_minutes,
    op.pageviews_per_session,
    CASE
        WHEN fv.first_visit_date = op.event_date THEN 'New'
        ELSE 'Returning'
    END                                        AS user_type,
    
    GREATEST(
        COALESCE(op.sys_audit_updated_on, TIMESTAMP '1900-01-01'),
        COALESCE(ls.sys_audit_updated_on, TIMESTAMP '1900-01-01'),
        COALESCE(t.sys_audit_updated_on,  TIMESTAMP '1900-01-01'),
        COALESCE(p.sys_audit_updated_on,  TIMESTAMP '1900-01-01'),
        COALESCE(sd.sys_audit_updated_on, TIMESTAMP '1900-01-01'),
        COALESCE(ed.sys_audit_updated_on, TIMESTAMP '1900-01-01')
    ) AS sys_audit_updated_on

FROM ordered_pageviews op
LEFT JOIN login_sessions ls  ON op.unique_session = ls.unique_session
LEFT JOIN trials         t   ON op.unique_session = t.unique_session
LEFT JOIN payments       p   ON op.unique_session = p.unique_session
LEFT JOIN session_data   sd  ON op.unique_session = sd.unique_session
LEFT JOIN first_visits   fv  ON op.user_pseudo_id  = fv.user_pseudo_id
LEFT JOIN event_devices  ed  ON op.unique_session = ed.unique_session