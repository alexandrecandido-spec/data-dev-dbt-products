{{config(
    materialized = 'incremental',
    unique_key = 'invoice_state_id',
    on_schema_change = 'fail',
    tags = ['product', 'daily-9am']
)}}

with nuvem_chat_invoice_state as (
    SELECT 
    year_month_code,
    id,
    invoice_id,
    name,
    created_at,
    state_id,
    CAST(discr AS STRING) as discr
    FROM {{ source('stg_nuvemchat', 'invoice_state') }} AS ncis
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['invoice_state_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    year_month_code,
    nuvem_chat_invoice_state.id invoice_state_id,
    invoice_id,
    created_at invoice_state_created_at,
    state_id,
    discr invoice_state,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM nuvem_chat_invoice_state
LEFT JOIN existing_data e ON nuvem_chat_invoice_state.id = e.invoice_state_id