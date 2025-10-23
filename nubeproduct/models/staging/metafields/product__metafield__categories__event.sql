{{
    config(
        materialized='incremental',
        unique_key='uuid',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}
with metafield_categories as (
    SELECT 
    uuid,
    namespace,
    key,
    store_id,
    owner_resource,
    value_type,
    source,
    name,
    description,
    read_only,
    app_id,
    created_at,
    updated_at,
    deleted_at
    FROM {{ source('stg_metafields', 'metafield_categories') }} AS mpv
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['uuid', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    metafield_categories.uuid,
    namespace,
    key,
    store_id,
    owner_resource,
    value_type,
    source,
    name,
    description,
    read_only,
    app_id,
    created_at,
    updated_at,
    deleted_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM metafield_categories
LEFT JOIN existing_data e ON metafield_categories.uuid = e.uuid