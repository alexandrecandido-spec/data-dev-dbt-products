SELECT
    u_user_pseudo_id,
    unique_session,
    country as mpv_country,
    device_category as mpv_category,
    event_date as mpv_event_date,
    event_timestamp as mpv_event_timestamp,
    env as mpv_env,
    event_page as mpv_page,
    landing_page as mpv_landing_page,
    last_source as mpv_last_source,
    last_medium as mpv_last_medium,
    last_campaign as mpv_last_campaign
FROM {{ ref('_int__ga4_page_view_events') }}