{{config(
    materialized = 'incremental',
    unique_key = 'invoice_id',
    on_schema_change = 'fail',
    tags = ['product', 'daily-10am']
)}}

with nuvem_chat_invoice as (
    SELECT 
    year_month_code,
    id,
    store_id,
    cost_total,
    created_at,
    cost_conversation,
    count_conversation,
    start_cycle_date,
    end_cycle_date,
    extra_grace_days
    FROM {{ source('stg_nuvemchat', 'invoice') }} AS nci
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['invoice_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    year_month_code,
    nuvem_chat_invoice.id invoice_id,
    store_id cn_store_id,
    cost_total invoice_cost_total,
    created_at invoice_created_at,
    cost_conversation invoice_cost_conversation,
    count_conversation invoice_count_conversation,
    start_cycle_date invoice_start_cycle_date,
    end_cycle_date invoice_end_cycle_date,
    extra_grace_days,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM nuvem_chat_invoice
LEFT JOIN existing_data e ON nuvem_chat_invoice.id = e.invoice_id