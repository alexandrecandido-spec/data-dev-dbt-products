{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id', 'conversation_created_at', 'conversation_type'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, [
        'store_id',
        'conversation_created_at',
        'conversation_type',
        'sys_audit_created_on',
        'sys_audit_created_by'
    ]) }}
),

base AS (
    SELECT
        s.store_id,
        co.cn_store_id,
        s.cn_merchant_name,
        s.onboarding,
        s.installed_at,
        s.trial_start_date,
        s.trial_end_date,
        s.cycle_start_date,
        s.cycle_end_date,
        s.last_invoice_id,
        s.invoice_created_at,
        s.invoice_start_cycle_date,
        s.invoice_end_cycle_date,
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
        co.conversation_created_at,
        CASE WHEN co.conversation_created_at BETWEEN s.trial_start_date AND s.trial_end_date THEN TRUE ELSE FALSE END AS is_in_trial,
        CASE WHEN co.has_ai_message = 1 THEN TRUE ELSE FALSE END AS has_ai_message,
        CASE 
            WHEN co.has_ai_message = 1 AND co.has_store_message = 1 THEN 'both'
            WHEN co.has_ai_message = 1 AND co.has_store_message = 0 THEN 'only ai'
            WHEN co.has_ai_message = 0 AND co.has_store_message = 1 THEN 'only store'
            ELSE 'other'
        END AS conversation_type,
        co.conversation_id
    FROM {{ ref('_int_product__nuvemchat_conversation_flags') }} co
    JOIN {{ ref('product_nuvemchat_stores') }} s
        ON co.cn_store_id = s.cn_store_id

    {% if is_incremental() %}
    WHERE co.max_combined_sys_audit_updated_on >= (SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }})
       OR s.sys_audit_updated_on >= (SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }})
    {% endif %}
),

aggregated AS (
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
        conversation_created_at,
        is_in_trial,
        has_ai_message,
        conversation_type,
        COUNT(DISTINCT conversation_id) AS total_conversations
    FROM base
    GROUP BY ALL
)

SELECT
    a.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM aggregated a
LEFT JOIN existing_data e
    ON e.store_id = a.store_id
    AND e.conversation_created_at = a.conversation_created_at
    AND e.conversation_type = a.conversation_type
