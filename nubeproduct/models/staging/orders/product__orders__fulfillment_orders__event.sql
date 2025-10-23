{{
    config(
        materialized='incremental',
        unique_key='id',
        partition_by='year_month_code',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}


WITH source AS (
    SELECT 
        year_month_code,
        id,
        store_id,
        order_id,
        fulfillment_order_id,
        number,
        location_id,
        location_name,
        shippable,
        carrier_name,
        option_name,
        shipping_type,
        status,
        tracking_code,
        line_items,
        created_at,
        updated_at
    FROM {{ source('stg_orders', 'mwp_orders_fulfillments') }}
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 hour' from {{ this }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    year_month_code,
    source.id,
    store_id,
    order_id,
    fulfillment_order_id,
    number,
    location_id,
    location_name,
    shippable,
    carrier_name,
    option_name,
    shipping_type,
    status,
    tracking_code,
    line_items,
    created_at,
    updated_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.id = e.id
