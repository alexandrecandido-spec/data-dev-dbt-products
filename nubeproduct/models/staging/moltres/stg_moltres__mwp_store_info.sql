{{
    config(
        materialized='incremental',
        unique_key='store_id',
        on_schema_change='fail'
    )
}}


WITH source AS (
    SELECT 
        id,
        country,
        current_segment,
        churned_at,
        created_at,
        plan
    FROM {{ source('moltres', 'mwp_store_info') }}
    WHERE state != 4 
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    AND sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('moltres','mwp_store_info') }} )

    {% endif %}
)

SELECT 
    id as store_id,
    country,
    current_segment,
    churned_at,
    created_at,
    plan
FROM source 