{{config(
    materialized = 'incremental',
    unique_key = 'cn_store_id',
    on_schema_change = 'fail',
    tags = ['product', 'daily-10am']
)}}

with nuvem_chat_stores as (
    SELECT 
    year_month_code,
    id,
    CAST(name AS STRING) as name,
    created_at,
    updated_at,
    deleted_at,
    remote_store_id,
    billing_plan_id,
    ia_response_length_id,
    ia_purpose_id,
    ia_language_id,
    ia_tone_id,
    ia_personality_id,
    ia_operation_mode_id,
    CAST(closed_message AS STRING) as closed_message,
    CAST(high_demand_message AS STRING) as high_demand_message,
    ia_personalization,
    CAST(url AS STRING) as url,
    tools,
    services,
    emojies,
    personality_traits,
    agree_to_use_information_from_store,
    take_order_in_chat,
    onboarding,
    funnel_stage_id
    FROM {{ source('stg_nuvemchat', 'store') }} AS ncs
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['cn_store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    year_month_code,
    nuvem_chat_stores.id cn_store_id,
    name,
    created_at installed_at,
    updated_at,
    deleted_at,
    remote_store_id as store_id,
    billing_plan_id,
    ia_response_length_id,
    ia_purpose_id,
    ia_language_id,
    ia_tone_id,
    ia_personality_id,
    ia_operation_mode_id,
    closed_message,
    high_demand_message,
    ia_personalization,
    url,
    tools,
    services,
    emojies,
    personality_traits,
    agree_to_use_information_from_store,
    take_order_in_chat,
    onboarding,
    funnel_stage_id,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM nuvem_chat_stores
LEFT JOIN existing_data e ON nuvem_chat_stores.id = e.cn_store_id