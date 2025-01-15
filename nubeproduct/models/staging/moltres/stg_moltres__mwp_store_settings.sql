{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail'
    )
}}


WITH source AS (
    SELECT
        id,
        store_id, 
        type
    FROM {{ source('moltres', 'mwp_store_settings') }}

    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ source('moltres','mwp_store_settings') }} )

    {% endif %}
)

SELECT 
    id,
    type,
    COALESCE(type, 'undefined') as vertical
FROM source 