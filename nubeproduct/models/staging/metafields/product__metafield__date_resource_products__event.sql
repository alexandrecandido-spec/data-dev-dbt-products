{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}
with metafield_date_products as (
    SELECT 
    id,
    metafield_uuid,
    value,
    owner_id,
    created_at,
    updated_at
    FROM {{ source('stg_metafields', 'metafield_date_resource_products') }} AS mdrp
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    metafield_date_products.id,
    metafield_uuid,
    value,
    owner_id,
    created_at,
    updated_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM metafield_date_products
LEFT JOIN existing_data e ON metafield_date_products.id = e.id