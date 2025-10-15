SELECT
    pay_order_id,
    DATE(paid_at) AS payment_history_paid_at
FROM {{ ref('billing__payment_transaction') }}
WHERE status = 'SUCCESS'
