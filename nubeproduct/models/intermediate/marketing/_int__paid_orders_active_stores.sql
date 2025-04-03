WITH
blocked_stores AS (
    SELECT
        related_id
    FROM {{ source('intermediate', 'mwp_tags') }} as tg
    WHERE tg.type = 'store'
        AND (tg.tag = 'sre-block-store-429'
            OR tg.tag = 'sre-block-store-404')
),
stores_transactions AS (
    SELECT
        mo.store_id,
        COUNT(mo.id) as tx_last_90_days
    FROM {{ ref('stg_finance__orders_mwp_orders') }} as mo
    WHERE 1 = 1
        AND mo.completed_at BETWEEN date_add(current_date(), -90) AND current_date()
        AND mo.store_id NOT IN (SELECT related_id FROM blocked_stores)
        AND mo.payment_status = 'paid'
        AND mo.status <> 'cancelled'
        AND mo.total_in_usd <= 10000 AND total_in_usd >= -10000
    GROUP BY
        mo.store_id
)

SELECT
    msi.store_id,
    CASE WHEN st.tx_last_90_days > 0 THEN 1 ELSE 0 END AS has_transactions,
    CASE WHEN msi.churned_at IS NOT NULL THEN 1 ELSE 0 END AS is_churn,
    CASE WHEN msi.created_at >= date_add(current_date(), -90) THEN 1 ELSE 0 END AS is_new,
    CASE WHEN mpc.context LIKE '%freemium%' AND mpc.monthly = 0 THEN 1 ELSE 0 END AS is_freemium
FROM {{ ref('stg_moltres__mwp_store_info') }} as msi
LEFT JOIN stores_transactions as st ON st.store_id = msi.store_id
INNER JOIN{{ source('intermediate', 'mwp_plans_countries') }} as mpc ON msi.plan = mpc.id
