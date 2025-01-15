WITH analytics_events AS (
    SELECT *
    FROM {{ ref('stg_marketing__ga4_analytics_events') }}
    WHERE (event_name LIKE '%clicked%' OR event_name = 'scroll')
)

SELECT
    u_user_pseudo_id,
    unique_session,
    event_timestamp,
    event_name,
    event_page,
    event_action,
    device_category AS event_device
FROM analytics_events