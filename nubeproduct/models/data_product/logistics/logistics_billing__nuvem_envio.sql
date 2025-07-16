{{ 
    config(
        materialized='table', 
        on_schema_change='fail',
        tags = ["logistics", "billing", "daily-8am"]
    ) 
}}



SELECT
    store_id,
    external_pay_order_id,
    paid_order_id,
    billing_cycle_id,
    domain,
    cycle_status,
    payment_expiration_date,
    created_at,
    payment_history_paid_at,
    id_type,
    id_number,
    business_name,
    invoice_emission_date,
    invoice_number,
    billing_cycle_end_date,
    receipt_number,
    original_payment_value,
    payment_value,
    adjustment_value,
    invoice_value,
    receipt_value,
    penalty_value,
    payment_method_fee_value,
    correios_cost_value,
    jadlog_cost_value,
    loggi_cost_value,
    mandae_cost_value,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_logistics_billing__cycle_general') }}
WHERE rnk = 1