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


WITH db AS (
SELECT
  DATE(DATE_TRUNC('DAY', completed_at)) AS ref_date,
  store_id,
  domain,
  current_segment,
  vertical_name,
  plan,
  store_creation_date,
  store_state_name,
  country,
  'GMV' AS sum_type,
  COUNT(shipment_id) AS qty,
  SUM(gmv) AS total
FROM {{ ref('logistics_gsv__orders') }}
WHERE 1=1
  AND flg_gmv = 1
  AND completed_at IS NOT NULL
GROUP BY
  ref_date,
  store_id,
  domain,
  current_segment,
  vertical_name,
  plan,
  store_creation_date,
  store_state_name,
  country

UNION ALL

SELECT
  DATE(DATE_TRUNC('DAY', posted_at)) AS ref_date,
  store_id,
  domain,
  current_segment,
  vertical_name,
  plan,
  store_creation_date,
  store_state_name,
  country,
  'GSV' AS sum_type,
  COUNT(shipment_id) AS orders_qty,
  SUM(gsv) AS total_value
FROM {{ ref('logistics_gsv__orders') }}
WHERE 1=1
  AND flg_gsv = 1
  AND posted_at IS NOT NULL
GROUP BY
  ref_date,
  store_id,
  domain,
  current_segment,
  vertical_name,
  plan,
  store_creation_date,
  store_state_name,
  country
)

SELECT * FROM db
