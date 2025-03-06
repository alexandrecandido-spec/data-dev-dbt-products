{{
    config(
        materialized='incremental',
        unique_key='event_id',
        partition_by='year_month_code', 
        on_schema_change='fail',
        tags=["testing","manual"]
    )
}}


WITH source AS (
    SELECT 
        event_id,
        store_id,
        session_id,
        consumer_id
        timestamp,
        attributes,
        event,
        year_month_code
    FROM {{ source('online', 'events') }}
    WHERE year_month_code >= DATE_FORMAT(DATE_ADD(DAY, -31, CURRENT_DATE), 'yyyyMMdd')
    and event in ('checkout_filled_email', 'wallet_customer_identification', 'wallet_customer_login', 'checkout_start')

    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('online','events') }} )

    {% endif %}
)

SELECT 
    *,
    'test' as test2,
    {{ get_key_value('attributes', 'cart_id', is_array=false, value_type='bigint') }} as attributes_cart_id,
        {{ get_key_value('attributes', 'shipping_information', is_array=false) }} as attributes_shipping_information,
    lower( {{ get_key_value('attributes', 'email', is_array=false, value_type='string') }} ) as attributes_contact_email,
    {{ get_key_value('attributes', 'shipping_information', is_array=false, value_type='boolean', json_path='has_shipping_option') }} as has_shipping_option
    
FROM source