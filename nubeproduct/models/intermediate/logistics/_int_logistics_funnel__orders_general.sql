-- This intermediate model builds the order-level funnel, 
-- representing how many shipments (orders) move through each stage 
-- of the Nuvem Envio journey (NS sale → NE enabled → NE selected → labels created → posted).
-- The model provides both order and merchant context, allowing granular tracking 
-- of engagement and operational behavior over time.

WITH 
base AS (
  SELECT
    shipment_id,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    completed_at AS ref_date,
    DATE(DATE_TRUNC('WEEK', completed_at)) AS ref_week,
    DATE(DATE_TRUNC('MONTH', completed_at)) AS ref_month,
    flg_gmv,
    flg_ne_enabled,
    flg_ne_selected,
    delivery_status,
    country
  FROM {{ ref('logistics_gsv__orders') }} 
)

SELECT 
    '01. Orders NS' AS tier,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    ref_date,
    ref_week,
    ref_month,
    country,
    COUNT(shipment_id) AS qty
FROM base
WHERE flg_gmv = 1
GROUP BY 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

UNION ALL

SELECT 
    '02. Orders NE enabled' AS tier,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    ref_date,
    ref_week,
    ref_month,
    country,
    COUNT(shipment_id) AS qty
FROM base
WHERE flg_gmv = 1
    AND flg_ne_enabled = 1
GROUP BY 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

UNION ALL

SELECT 
    '03. Orders NE selected' AS tier,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    ref_date,
    ref_week,
    ref_month,
    country,
    COUNT(shipment_id) AS qty
FROM base
WHERE flg_gmv = 1
    AND flg_ne_enabled = 1
    AND flg_ne_selected = 1
GROUP BY 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

UNION ALL

SELECT 
    '04. Postage labels created' AS tier,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    ref_date,
    ref_week,
    ref_month,
    country,
    COUNT(shipment_id) AS qty
FROM base
WHERE flg_gmv = 1
    AND flg_ne_enabled = 1
    AND flg_ne_selected = 1
    AND delivery_status IN ('posted', 'created')
GROUP BY 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

UNION ALL

SELECT 
    '05. Posted NE orders' AS tier,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    store_creation_date,
    store_state_name,
    ref_date,
    ref_week,
    ref_month,
    country, 
    COUNT(shipment_id) AS qty
FROM base
WHERE flg_gmv = 1
    AND flg_ne_enabled = 1
    AND flg_ne_selected = 1
    AND delivery_status = 'posted'
GROUP BY 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12