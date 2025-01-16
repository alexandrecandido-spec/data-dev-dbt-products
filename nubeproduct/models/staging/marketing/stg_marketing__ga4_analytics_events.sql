
WITH source AS (
    SELECT 
    *,
    {{ get_property_value('event_params', 'ga_session_id', 'int_value') }} as session_id,
    {{ get_property_value('event_params', 'page_location', 'string_value') }} as event_page,
    {{ get_property_value('event_params', 'eventAction', 'string_value') }} as event_action,
    {{ get_property_value('event_params', 'source', 'string_value') }} as event_source,
    {{ get_property_value('event_params', 'medium', 'string_value') }} as event_medium,
    {{ get_property_value('event_params', 'campaign', 'string_value') }} as event_campaign,
    {{ get_property_value('event_params', 'env', 'string_value') }} as env

    FROM {{ source('marketing', 'analytics_events') }}
    WHERE year_month_code >= 202501

)

SELECT distinct
    CONCAT(source, '-', user_pseudo_id) AS u_user_pseudo_id,
    CONCAT(source, '-', user_pseudo_id, '-', session_id) AS unique_session,
    session_id,
    event_page,
    event_action,
    event_source,
    event_medium,
    event_campaign,
    env,
    event_bundle_sequence_id,
    source,
    user_pseudo_id,
    event_date as event_date_str,
    to_date(event_date, 'yyyyMMdd') as event_date,
    event_timestamp,
    event_name,
    event_params,
    device.category AS device_category,
    geo.country as country,
    year_month_code,
    year,
    month,
    day
FROM source