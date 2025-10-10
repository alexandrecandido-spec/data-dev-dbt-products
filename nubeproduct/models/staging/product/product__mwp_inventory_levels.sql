{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}
with inventory_levels as (
    SELECT 
    year_month_code,
    id,
    variant_id,
    location_id,
    stock,
    created_at,
    updated_at,
    deleted_at
    FROM {{ source('stg_catalog', 'mwp_inventory_levels') }} AS mil
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
    year_month_code,
    inventory_levels.id,
    variant_id,
    location_id,
    stock,
    created_at,
    updated_at,
    deleted_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM inventory_levels
LEFT JOIN existing_data e ON inventory_levels.id = e.id