{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['invoice_id'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

with exchange as (
    SELECT
        processed_at,
        country_currency_code,
        ROUND(direct_exchange_rate,1) direct_exchange_rate,
        sys_audit_updated_on
    FROM
        {{ ref('finance_exchange_rate') }}
    WHERE
        processed_at >= date('2025-01-01')
)

SELECT
    s.store_id,
    s.cn_store_id,
    s.cn_merchant_name,
    s.onboarding,
    s.installed_at,
    s.trial_start_date,
    s.trial_end_date,
    s.cycle_start_date,
    s.cycle_end_date,
    s.last_invoice_id,
    s.invoice_created_at latest_invoice_created_at,
    s.invoice_start_cycle_date latest_invoice_start_cycle_date,
    s.invoice_end_cycle_date latest_invoice_end_cycle_date,
    s.days_since_last_invoice,
    s.last_invoice_count_conversation,
    s.paid_invoices,
    s.last_paid_date,
    s.first_paid_date,
    s.grace_until,
    s.current_invoice_state,
    s.total_invoices,
    s.unpaid_invoices_since_last_paid,
    s.ai_conversations_after_invoice,
    s.conversations_after_trial,
    s.conversations_in_trial,
    s.ai_conv_last_3d,
    s.last_conversation_date,
    s.chatnube_state,
    s.chatnube_state_group,
    s.churned_date,
    s.country,
    s.plan_group,
    s.domain,
    s.state,
    s.tiendanube_state,
    s.current_segment,
    s.avg_gmv_usd_last_3m,
    s.avg_orders_last_3m,
    e.direct_exchange_rate,
    is.invoice_id,
    is.invoice_state,
    is.invoice_start_cycle_date,
    is.invoice_end_cycle_date,
    is.invoice_created_at,
    is.invoice_count_conversation,
    is.invoice_cost_total,
    is.invoice_cost_per_conversation,
    is.paid_date,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__nuvemchat_invoice_state') }} is 
LEFT JOIN {{ ref('_int_product__nuvemchat_stores_merchant_info') }} s ON s.cn_store_id = is.cn_store_id
LEFT JOIN exchange e ON s.country = e.country_currency_code AND e.processed_at = DATE(is.invoice_created_at)
{% if is_incremental() %}
WHERE GREATEST(
    COALESCE(s.max_combined_sys_audit_updated_on, '1900-01-01'),
    COALESCE(is.sys_audit_updated_on, '1900-01-01'),
    COALESCE(e.sys_audit_updated_on, '1900-01-01')
) >= (SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }})
{% endif %}