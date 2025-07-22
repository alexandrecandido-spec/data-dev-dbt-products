
{{
    config(
        materialized='table',
        on_schema_change='fail',
        tags=["logistics","daily-8am"]
    )
}}

SELECT DISTINCT
    payOrderId AS paid_order_id,
    DATE(paidAt) AS paid_at,
    status,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_billing', 'payment_transaction') }}