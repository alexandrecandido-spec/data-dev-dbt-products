{%- set MAX_TOTAL_USD_ABS = var('max_total_usd_abs_diff', 50.0) -%}
{%- set MAX_TOTAL_USD_REL = var('max_total_usd_rel_diff', 1e-5) -%}
{%- set MAX_MISSING_ROWS  = var('max_missing_rows', 0) -%}
{%- set CHECK_ORDERS = var('check_orders', false) -%}
{%- set MAX_TOTAL_ORDERS_DIFF = var('max_total_orders_diff', 0) -%}
{%- set CHECK_PRODUCTS = var('check_products', false) -%}
{%- set MAX_TOTAL_PRODUCTS_DIFF = var('max_total_products_diff', 0) -%}

WITH dp AS (
  SELECT
    store_id,
    reported_month,
    /* usa DOUBLE para sumar más rápido; ya redondeamos en el reporte */
    SUM(COALESCE(CAST(gmv       AS DOUBLE),0.0)) AS gmv,
    SUM(COALESCE(CAST(gmv_usd   AS DOUBLE),0.0)) AS gmv_usd,
    SUM(COALESCE(orders,0))                      AS orders,
    SUM(COALESCE(product_quantity,0))            AS product_quantity
  FROM {{ ref('g__general__deepdive_gmv_store__agg_monthly') }}
  GROUP BY 1,2
),
dp_months AS (
  SELECT DISTINCT reported_month FROM dp
),
dy AS (
  SELECT
    store_id,
    last_day(date) AS reported_month,
    SUM(COALESCE(CAST(gmv       AS DOUBLE),0.0)) AS gmv,
    SUM(COALESCE(CAST(gmv_usd   AS DOUBLE),0.0)) AS gmv_usd,
    SUM(COALESCE(orders,0))                      AS orders,
    SUM(COALESCE(products,0))                    AS product_quantity
  FROM {{ ref('g__operations__orders_gmv_store__agg_daily') }}
  WHERE last_day(date) IN (SELECT reported_month FROM dp_months)
  GROUP BY 1,2
),
base AS (
  -- Evitamos el FULL OUTER JOIN: unimos verticalmente con una “bandera de origen”
  SELECT 'dp' AS side, store_id, reported_month, gmv_usd, orders, product_quantity FROM dp
  UNION ALL
  SELECT 'dy' AS side, store_id, reported_month, gmv_usd, orders, product_quantity FROM dy
),
cmp AS (
  -- Un solo shuffle: agregamos por store–mes y separamos lados con SUM condicional
  SELECT
    store_id,
    reported_month,
    SUM(CASE WHEN side='dp' THEN gmv_usd ELSE 0.0 END) AS dp_gmv_usd,
    SUM(CASE WHEN side='dy' THEN gmv_usd ELSE 0.0 END) AS dy_gmv_usd,
    SUM(CASE WHEN side='dp' THEN orders  ELSE 0 END)   AS dp_orders,
    SUM(CASE WHEN side='dy' THEN orders  ELSE 0 END)   AS dy_orders,
    SUM(CASE WHEN side='dp' THEN product_quantity ELSE 0 END) AS dp_products,
    SUM(CASE WHEN side='dy' THEN product_quantity ELSE 0 END) AS dy_products,
    COUNT(DISTINCT side) AS sides_present               -- 1 => falta en un lado
  FROM base
  GROUP BY 1,2
),
agg AS (
  SELECT
    SUM(CASE WHEN sides_present = 1 THEN 1 ELSE 0 END) AS missing_rows,
    SUM(ABS(COALESCE(dp_gmv_usd,0.0) - COALESCE(dy_gmv_usd,0.0))) AS total_abs_diff_usd,
    SUM(COALESCE(dp_gmv_usd,0.0)) AS total_dp_usd,
    SUM(COALESCE(dy_gmv_usd,0.0)) AS total_dy_usd,
    SUM(ABS(COALESCE(dp_orders,0) - COALESCE(dy_orders,0))) AS total_orders_abs_diff,
    SUM(ABS(COALESCE(dp_products,0) - COALESCE(dy_products,0))) AS total_products_abs_diff
  FROM cmp
),
calc AS (
  SELECT
    *,
    GREATEST((COALESCE(total_dp_usd,0.0) + COALESCE(total_dy_usd,0.0)) / 2.0, 1.0) AS denom_usd
  FROM agg
),
limits AS (
  SELECT
    {{ MAX_MISSING_ROWS }}        AS max_missing_rows,
    {{ MAX_TOTAL_USD_ABS }}       AS max_total_usd_abs,
    {{ MAX_TOTAL_USD_REL }}       AS max_total_usd_rel,
    {{ MAX_TOTAL_ORDERS_DIFF }}   AS max_total_orders_diff,
    {{ MAX_TOTAL_PRODUCTS_DIFF }} AS max_total_products_diff
),
violations AS (
  SELECT 'missing_rows' AS issue, CAST(c.missing_rows AS STRING) AS actual, CAST(l.max_missing_rows AS STRING) AS threshold
  FROM calc c, limits l
  WHERE c.missing_rows > l.max_missing_rows

  UNION ALL
  SELECT 'total_abs_diff_usd', CAST(c.total_abs_diff_usd AS STRING), CAST(l.max_total_usd_abs AS STRING)
  FROM calc c, limits l
  WHERE c.total_abs_diff_usd > l.max_total_usd_abs

  UNION ALL
  SELECT 'total_rel_diff_usd', CAST(c.total_abs_diff_usd / c.denom_usd AS STRING), CAST(l.max_total_usd_rel AS STRING)
  FROM calc c, limits l
  WHERE (c.total_abs_diff_usd / c.denom_usd) > l.max_total_usd_rel

  {%- if CHECK_ORDERS %}
  UNION ALL
  SELECT 'total_orders_abs_diff', CAST(c.total_orders_abs_diff AS STRING), CAST(l.max_total_orders_diff AS STRING)
  FROM calc c, limits l
  WHERE c.total_orders_abs_diff > l.max_total_orders_diff
  {%- endif %}

  {%- if CHECK_PRODUCTS %}
  UNION ALL
  SELECT 'total_products_abs_diff', CAST(c.total_products_abs_diff AS STRING), CAST(l.max_total_products_diff AS STRING)
  FROM calc c, limits l
  WHERE c.total_products_abs_diff > l.max_total_products_diff
  {%- endif %}
)
SELECT * FROM violations
