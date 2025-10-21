{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

SELECT
    store_id,
    cn_store_id,
    cn_merchant_name,
    onboarding,
    installed_at,
    trial_start_date,
    trial_end_date,
    cycle_start_date,
    cycle_end_date,
    last_invoice_id,
    invoice_created_at,
    invoice_start_cycle_date,
    invoice_end_cycle_date,
    days_since_last_invoice,
    last_invoice_count_conversation,
    paid_invoices,
    last_paid_date,
    first_paid_date,
    grace_until,
    overall_grace_until,
    current_invoice_state,
    total_invoices,
    unpaid_invoices_since_last_paid,
    ai_conversations_after_invoice,
    conversations_after_trial,
    conversations_in_trial,
    ai_conv_last_3d,
    last_conversation_date,
    chatnube_state,
    chatnube_state_group,
    churned_date,
    country,
    plan_group,
    domain,
    state,
    tiendanube_state,
    current_segment,
    avg_gmv_usd_last_3m,
    avg_orders_last_3m,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__nuvemchat_stores_merchant_info') }} s
    {% if is_incremental() %}
WHERE s.max_combined_sys_audit_updated_on >= (SELECT coalesce(max(sys_audit_updated_on),'1900-01-01') FROM {{ this }})
    {% endif %}