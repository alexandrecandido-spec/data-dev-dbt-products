WITH blocked_stores AS (
    SELECT related_id
    FROM {{ source('int_moltres', 'mwp_tags') }} AS tg
    WHERE tg.type = 'store'
      AND tg.tag IN ('sre-block-store-429', 'sre-block-store-404')
),

base_orders AS (
    SELECT *
    FROM {{ ref('company_metrics_paid_orders') }}
    WHERE store_id NOT IN (SELECT related_id FROM blocked_stores)
      AND year_month_day_code  >=  20221003
),

orders_with_sales_90d AS (
    SELECT
        store_id,
        completed_at,
        COUNT(*) OVER (
            PARTITION BY store_id
            ORDER BY completed_at
            RANGE BETWEEN INTERVAL 90 DAYS PRECEDING AND CURRENT ROW
        ) AS sales_90d
    FROM base_orders
)

SELECT
    store_id,
    completed_at
FROM orders_with_sales_90d
WHERE completed_at >= DATE '2023-01-01'
  AND sales_90d >= 7
