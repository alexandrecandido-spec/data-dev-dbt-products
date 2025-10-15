-- Filters all paid online orders (non-POS) from company_metrics_paid_orders for Brazil, Argentina, and Mexico since 2023. 
-- It marks them as “Paid orders” and defines them as valid GMV transactions.

SELECT
  CAST(store_id AS BIGINT) AS store_id,
  CAST(id AS STRING) AS order_id,
  completed_at,
  'paid' AS payment_status,
  'Paid order'  AS class,
  0   AS flg_gsv,
  0   AS flg_detached,
  0   AS flg_shipment,
  1   AS flg_gmv,
  0   AS gsv,
  total,
  country,
  shipping_method,
  'Outros' AS selected_shipping_partner
FROM {{ ref('company_metrics_paid_orders') }}
WHERE year_month_day_code >= 20230101
  AND platform_type = 'on'
  AND storefront <> 'pos'
  AND country IN ('BR', 'AR', 'MX')