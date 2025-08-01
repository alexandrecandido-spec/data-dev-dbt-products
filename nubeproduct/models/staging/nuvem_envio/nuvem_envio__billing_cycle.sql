{{
    config(
        materialized='table',
        unique_key= 'billing_cycle_id',
        on_schema_change='fail',
        tags=["logistics","daily-8am"]
    )
}}

SELECT
    id AS billing_cycle_id,
    external_store_id,
    original_payment_value,
    payment_value,
    receipt_value,
    penalty_value,
    adjustment_value,
    cycle_status,
    payment_expiration_date,
    DATE(created_at) AS created_at,
    DATE(payment_status_updated_at) AS payment_status_updated_date,
    payment_method_fee_value,
    DATE(invoice_emission_date) AS invoice_emission_date,
    invoice_number,
    billing_cycle_end_date,
    invoice_value,
    external_pay_order_id,
    external_receipt_id,
    currency,
    year_month_code,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_nuvem_envio_billing', 'billing_cycle') }}