-- This intermediate model aggregates merchant-level funnel data 
-- across daily, weekly, and monthly granularities.
-- It tracks merchant activation and engagement stages with Nuvem Envio,
-- starting from merchants generating NS sales up to those posting shipments.
-- Each tier represents a sequential step in the merchant adoption funnel.

WITH 
base AS (
  SELECT
    shipment_id,
    store_id,
    domain,
    current_segment,
    vertical_name,
    plan,
    DATE(completed_at) AS ref_date,
    DATE(DATE_TRUNC('WEEK', completed_at)) AS ref_week,
    DATE(DATE_TRUNC('MONTH', completed_at)) AS ref_month,
    flg_gmv,
    flg_ne_enabled,
    flg_ne_selected,
    delivery_status,
    country
  FROM {{ ref('logistics_gsv__orders') }}
)

-- DAILY
, daily AS (
  SELECT
    'day' AS granularity,
    '01. Merchants with NS sales' AS tier,
    current_segment,
    vertical_name,
    plan,
    country,
    ref_date AS ref_period,
    COUNT(DISTINCT store_id) AS qty
  FROM base
  WHERE flg_gmv = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_date

  UNION ALL

  SELECT
    'day',
    '02. Merchants with NE enabled',
    current_segment, vertical_name, plan, country, ref_date,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_date

  UNION ALL

  SELECT
    'day',
    '03. Merchants with NE selected',
    current_segment, vertical_name, plan, country, ref_date,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_date

  UNION ALL

  SELECT
    'day',
    '04. Merchants with labels created',
    current_segment, vertical_name, plan, country, ref_date,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1 AND delivery_status IN ('posted','created')
  GROUP BY current_segment, vertical_name, plan, country, ref_date

  UNION ALL

  SELECT
    'day',
    '05. Merchants posting with NE',
    current_segment, vertical_name, plan, country, ref_date,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1 AND delivery_status = 'posted'
  GROUP BY current_segment, vertical_name, plan, country, ref_date
)

-- WEEKLY: same lógica, mas agrupando por ref_week
, weekly AS (
  SELECT
    'week' AS granularity,
    '01. Merchants with NS sales' AS tier,
    current_segment,
    vertical_name,
    plan,
    country,
    ref_week AS ref_period,
    COUNT(DISTINCT store_id) AS qty
  FROM base
  WHERE flg_gmv = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_week

  UNION ALL

  SELECT
    'week',
    '02. Merchants with NE enabled',
    current_segment, vertical_name, plan, country, ref_week,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_week

  UNION ALL

  SELECT
    'week',
    '03. Merchants with NE selected',
    current_segment, vertical_name, plan, country, ref_week,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_week

  UNION ALL

  SELECT
    'week',
    '04. Merchants with labels created',
    current_segment, vertical_name, plan, country, ref_week,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1 AND delivery_status IN ('posted','created')
  GROUP BY current_segment, vertical_name, plan, country, ref_week

  UNION ALL

  SELECT
    'week',
    '05. Merchants posting with NE',
    current_segment, vertical_name, plan, country, ref_week,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1 AND delivery_status = 'posted'
  GROUP BY current_segment, vertical_name, plan, country, ref_week
)

-- MONTHLY
, monthly AS (
  SELECT
    'month' AS granularity,
    '01. Merchants with NS sales' AS tier,
    current_segment,
    vertical_name,
    plan,
    country,
    ref_month AS ref_period,
    COUNT(DISTINCT store_id) AS qty
  FROM base
  WHERE flg_gmv = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_month

  UNION ALL

  SELECT
    'month',
    '02. Merchants with NE enabled',
    current_segment, vertical_name, plan, country, ref_month,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_month

  UNION ALL

  SELECT
    'month',
    '03. Merchants with NE selected',
    current_segment, vertical_name, plan, country, ref_month,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1
  GROUP BY current_segment, vertical_name, plan, country, ref_month

  UNION ALL

  SELECT
    'month',
    '04. Merchants with labels created',
    current_segment, vertical_name, plan, country, ref_month,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1 AND delivery_status IN ('posted','created')
  GROUP BY current_segment, vertical_name, plan, country, ref_month

  UNION ALL

  SELECT
    'month',
    '05. Merchants posting with NE',
    current_segment, vertical_name, plan, country, ref_month,
    COUNT(DISTINCT store_id)
  FROM base
  WHERE flg_gmv = 1 AND flg_ne_enabled = 1 AND flg_ne_selected = 1 AND delivery_status = 'posted'
  GROUP BY current_segment, vertical_name, plan, country, ref_month
),

funnel AS (
  SELECT * FROM daily
  UNION ALL
  SELECT * FROM weekly
  UNION ALL
  SELECT * FROM monthly
  ORDER BY granularity, tier, current_segment, vertical_name, plan, country, ref_period
)

SELECT * FROM funnel