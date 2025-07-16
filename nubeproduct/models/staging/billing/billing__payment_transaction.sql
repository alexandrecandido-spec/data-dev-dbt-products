
{{
    config(
        materialized='table',
        on_schema_change='fail',
        tags=["billing","daily-8am"]
    )
}}

SELECT DISTINCT
    payOrderId,
    DATE(paidAt) AS paid_at,
    status
FROM {{ source('stg_billing', 'payment_transaction') }}