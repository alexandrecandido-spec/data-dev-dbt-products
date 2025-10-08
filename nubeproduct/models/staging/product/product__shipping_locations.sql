{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags=["product","daily-10am"]
    )
}}
with locations as (
    SELECT 
        address,
        chosenAsDefaultAt,
        createdAt,
        deletedAt,
        id,
        isDraft,
        name,
        priority,
        storeId,
        tags,
        updatedAt,
        year_month_code
    FROM {{ source('stg_shipping', 'locations') }} AS l
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    address,
    chosenAsDefaultAt,
    createdAt,
    deletedAt,
    locations.id,
    isDraft,
    name,
    priority,
    storeId,
    tags,
    updatedAt,
    year_month_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM locations
LEFT JOIN existing_data e ON locations.id = e.id