-- Owner: YAN GERMANO
SELECT
    t.partner_id,
    t.country_code,
    t.is_store_blocked,
    t.new_seller,
    CAST(g.date AS DATE) AS date,

    SUM(g.gmv) AS total_gmv,
    SUM(g.orders) AS total_orders
FROM {{ ref('_int__affiliates_general_tabla') }} AS t
INNER JOIN {{ ref('g__operations__orders_gmv_store__agg_daily') }} AS g
    ON t.store_id = g.store_id
WHERE g.date >= '2023-01-01'
GROUP BY 1, 2, 3, 4, 5
