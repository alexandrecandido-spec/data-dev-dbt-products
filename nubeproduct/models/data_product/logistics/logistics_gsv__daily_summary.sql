-- Daily aggregated metrics for orders and shipments.
-- Key outputs:
--   - Number of GSV orders + total GSV value
--   - Number of GMV orders + total GMV value
-- Granularity: day + store + segment.
-- Ordered with most recent dates first.

{{ 
    config(
        materialized='table', 
        on_schema_change='fail',
        tags = ["logistics", "daily-8am"]
    ) 
}}

WITH
base AS (
  SELECT
    DATE(DATE_TRUNC('DAY', COALESCE(final_date, completed_at))) AS date_ref,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    country,
    flg_gsv,
    flg_gmv,
    gsv,
    gmv,
    shipment_id
  FROM {{ ref('logistics_gsv__orders') }}
)
SELECT
  date_ref,
  store_id,
  domain,
  current_segment,
  vertical_name,
  plan,
  store_creation_date,
  store_state_name,
  country,
  SUM(CASE WHEN flg_gsv = 1 THEN 1 ELSE 0 END) AS qtd_orders_gsv,
  SUM(CASE WHEN flg_gsv = 1 THEN CAST(gsv AS DOUBLE) ELSE 0 END) AS total_gsv,
  SUM(CASE WHEN flg_gmv = 1 THEN 1 ELSE 0 END) AS qtd_orders_gmv,
  SUM(CASE WHEN flg_gmv = 1 THEN CAST(gmv AS DOUBLE) ELSE 0 END) AS total_gmv
FROM base
WHERE date_ref IS NOT NULL
GROUP BY
  date_ref,
  store_id,
  domain,
  current_segment,
  vertical_name,
  plan,
  store_creation_date,
  store_state_name,
  country
ORDER BY date_ref DESC