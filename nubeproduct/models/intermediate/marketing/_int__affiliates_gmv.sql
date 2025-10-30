SELECT
    t.partner_id,
    t.country_code,
    CAST(g.completed_at AS DATE) AS date,

    SUM(g.gmv) AS total_gmv,
    SUM(g.orders_quantity) AS total_orders,
    SUM(g.gmv_30d) AS gmv_30d,
    SUM(g.orders_30d) AS orders_30d,
    SUM(g.gmv_90d) AS gmv_90d,
    SUM(g.orders_90d) AS orders_90d

FROM {{ ref('_int__affiliates_general_tabla') }} AS t
INNER JOIN {{ ref('g__general__gmv_by_mkt_source__agg_daily') }} AS g
    ON t.store_id = g.store_id
WHERE g.completed_at >= '2023-01-01'
GROUP BY 1, 2, 3
