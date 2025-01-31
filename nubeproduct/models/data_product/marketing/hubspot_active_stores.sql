SELECT store_id
FROM {{ ref('_int__paid_orders_active_stores') }}
WHERE
    (
        is_freemium = 0
        AND is_churn = 0
    ) OR
    (
        is_freemium = 1
        AND is_churn = 0
        AND is_new = 1
    ) OR
    (
        is_freemium = 1
        AND is_churn = 0
        AND is_new = 0
        AND has_transactions = 1
    )
