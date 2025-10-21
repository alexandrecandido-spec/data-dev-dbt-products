{{
    config(
        materialized='incremental',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=['dimensions', 'daily-4am']
    )
}}

WITH source AS 
(
SELECT 
 a.store_id, 
 b.business_size_id, 
 a.sys_audit_updated_on
FROM {{ source('stg_moltres','mwp_store_settings') }} a
INNER JOIN {{ ref('dimension__attributes__business_size__ref') }} b ON a.business_size = b.business_size_name
WHERE 
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    a.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% else %}
        1 = 1 -- this will always be true if not incremental
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)


SELECT 
a.store_id,
A.business_size_id,
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM source a
LEFT JOIN existing_data e ON a.store_id = e.store_id