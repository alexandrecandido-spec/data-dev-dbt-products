SELECT
    u_user_pseudo_id,
    unique_session,
    event_timestamp,
    event_name,
    event_page,
    event_action,
    event_device
FROM {{ ref('_int__ga4_user_sessions') }}