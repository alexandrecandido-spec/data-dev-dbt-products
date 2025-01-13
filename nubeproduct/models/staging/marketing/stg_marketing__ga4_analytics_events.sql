{{
    config(
        materialized='incremental',
        unique_key='event_bundle_sequence_id',
        on_schema_change='fail'
    )
}}


WITH source AS (
    SELECT *
    FROM {{ source('marketing', 'analytics_events') }}
    WHERE event_date = '20230701'
      AND (event_name LIKE '%clicked%' OR event_name = 'scroll')
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    and sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('marketing','analytics_events') }} )

    {% endif %}
)

SELECT
    event_bundle_sequence_id,
    source,
    user_pseudo_id,
    event_timestamp,
    event_name,
    event_params,
    {{ get_property_value('event_params', 'ga_session_id', 'int_value') }} as session_id,
    {{ get_property_value('event_params', 'page_location', 'string_value') }} as event_page,
    {{ get_property_value('event_params', 'eventAction', 'string_value') }} as event_action,
    device.category AS device_category
FROM source