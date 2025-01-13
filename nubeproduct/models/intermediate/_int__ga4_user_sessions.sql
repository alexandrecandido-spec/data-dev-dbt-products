WITH analytics_events AS (
    SELECT *
    FROM {{ ref('stg_marketing__ga4_analytics_events') }}
)

SELECT
    CONCAT(source, '-', user_pseudo_id) AS u_user_pseudo_id,
    CONCAT(source, '-', user_pseudo_id, '-', session_id) AS unique_session,
    event_timestamp,
    event_name,
    event_page,
    event_action,
    device_category AS event_device
FROM analytics_events