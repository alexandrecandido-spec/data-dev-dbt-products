{{
    config(
        materialized='incremental',
        unique_key='shipping_carrier_id',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}
with shipping_carriers as (
    SELECT 
        id,
        store_id,
        name,
        types,
        status,
        app_id,
        created_at,
        updated_at,
        deleted_at
    FROM {{ source('stg_moltres', 'mwp_shipping_carriers') }} AS sc
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['shipping_carrier_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    shipping_carriers.id shipping_carrier_id,
    store_id,
    name shipping_carrier_name,
    types,
    status,
    app_id,
    created_at,
    updated_at,
    deleted_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM shipping_carriers
LEFT JOIN existing_data e ON shipping_carriers.id = e.shipping_carrier_id