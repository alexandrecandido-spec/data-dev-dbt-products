{{config(
    materialized = 'incremental',
    unique_key = 'billing_plan_id',
    on_schema_change = 'fail',
    tags = ['product', 'daily-9am']
)}}

with nuvem_chat_billing_plan as (
    SELECT 
    year_month_code,
    id,
    created_at,
    plan_id,
    store_id,
    trial_id,
    start_date,
    end_free_trial_date,
    cycle_start_date,
    cycle_end_date
    FROM {{ source('stg_nuvemchat', 'billing_plan') }} AS ncbp
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),

existing_data AS (
    {{ get_existing_data(this, ['billing_plan_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    year_month_code,
    nuvem_chat_billing_plan.id billing_plan_id,
    created_at,
    plan_id,
    store_id as cn_store_id,
    trial_id,
    start_date trial_start_date,
    end_free_trial_date trial_end_date,
    cycle_start_date billing_cycle_start_date,
    cycle_end_date billing_cycle_end_date,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM nuvem_chat_billing_plan
LEFT JOIN existing_data e ON nuvem_chat_billing_plan.id = e.billing_plan_id