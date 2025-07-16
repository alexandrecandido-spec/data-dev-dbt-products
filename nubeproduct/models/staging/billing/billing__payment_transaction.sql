
{{
    config(
        materialized='table',
        on_schema_change='fail',
        tags=["billing","daily-8am"]
    )
}}

SELECT DISTINCT
    payOrderId AS paid_order_id,
    DATE(paidAt) AS paid_at,
    status
FROM {{ source('stg_billing', 'payment_transaction') }}