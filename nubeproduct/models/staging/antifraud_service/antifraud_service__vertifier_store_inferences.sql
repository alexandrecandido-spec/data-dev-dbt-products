{{
    config(
        materialized='incremental',
        unique_key=['store_id','created_at'],
        on_schema_change='fail',
        tags=["operations","daily-6am"]
    )
}}

WITH source AS (
    SELECT 
    cast(storeid AS bigint) AS store_id,
    cast(primary.name as string) AS vertifier,
    createdat as created_at
    FROM {{ source('stg_antifraud_service', 'vertifier_store_inferences') }}
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['store_id', 'created_at', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    a.store_id,
    a.vertifier,
    a.created_at,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source a
LEFT JOIN existing_data e ON a.store_id = e.store_id and a.created_at = e.created_at