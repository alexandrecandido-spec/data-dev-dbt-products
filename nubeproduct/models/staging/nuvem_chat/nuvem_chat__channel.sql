{{config(
    materialized = 'incremental',
    unique_key = 'channel_id',
    on_schema_change = 'fail',
    tags = ['product', 'daily-9am']
)}}

with nuvem_chat_channel as (
    SELECT 
    year_month_code,
    id,
    store_id,
    created_at,
    updated_at,
    deleted_at,
    CAST(discr AS STRING) as discr
    FROM {{ source('stg_nuvemchat', 'channel') }} AS ncc
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['channel_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    year_month_code,
    nuvem_chat_channel.id channel_id,
    store_id cn_store_id,
    created_at,
    updated_at,
    deleted_at,
    discr channel_discr,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM nuvem_chat_channel
LEFT JOIN existing_data e ON nuvem_chat_channel.id = e.channel_id