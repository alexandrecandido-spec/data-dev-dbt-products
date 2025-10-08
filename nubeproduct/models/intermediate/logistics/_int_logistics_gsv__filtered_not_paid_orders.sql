-- Selects not-paid (cancelled) orders.
-- Filters applied:
--   - Year >= 2023
--   - Excludes POS storefront
--   - Order total <= 10,000 USD
--   - Brazil only
--   - Excludes orders already present as paid
-- Marks records as "Cancelled order".

WITH
filtered_not_paid_orders AS (
  SELECT
    o.store_id, 
    CAST(o.id AS STRING) AS order_id,
    CAST(o.completed_at AS DATE) AS completed_at, 
    o.payment_status, 
    o.total, 
    o.shipping_method 
  FROM {{ ref('orders__mwp_orders') }} o 
  WHERE o.year_month_day_code >= 20230101
    AND o.storefront <> 'pos'
    AND o.id IS NOT NULL
    AND o.total_in_usd <= 10000
)

SELECT
    fnpo.store_id, 
    fnpo.order_id, 
    fnpo.completed_at, 
    fnpo.payment_status, 
    'Cancelled order'  AS class,
    0   AS flg_gsv,
    0   AS flg_detached,
    0   AS flg_shipment,
    0   AS flg_gmv,
    0   AS gsv,
    fnpo.total, 
    i.country, 
    fnpo.shipping_method, 
    'Outros' AS selected_shipping_partner
FROM filtered_not_paid_orders fnpo 
    INNER JOIN {{ ref('moltres__mwp_store_info') }} i 
        ON fnpo.store_id = i.store_id
        AND i.country IN ('BR', 'AR', 'MX')
        AND i.state <> 4
    LEFT JOIN {{ ref('_int_logistics_gsv__filtered_paid_orders') }} p 
      ON p.order_id = fnpo.order_id
  WHERE p.order_id IS NULL