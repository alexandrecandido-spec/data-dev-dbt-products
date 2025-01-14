{{
    config(
        materialized='incremental',
        unique_key='event_bundle_sequence_id',
        on_schema_change='fail'
    )
}}


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

    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('marketing','analytics_events') }} )

    {% endif %}
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