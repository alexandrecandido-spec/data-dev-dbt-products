-- 🔍 REPORTE DIAGNÓSTICO CORREGIDO: Con timezone AR → UTC
-- Período LOCAL AR: 2025-10-26T20:00:00 a 2025-10-29T23:59:59
-- Período UTC:      2025-10-26T23:00:00 a 2025-10-30T02:59:59

diagnostic_report_sql = """
WITH period_orders AS (
  SELECT *
  FROM orders_scoped 
  WHERE completed_at >= TIMESTAMP('2025-10-26T23:00:00.000Z')  -- ✅ 20:00 AR = 23:00 UTC
    AND completed_at <= TIMESTAMP('2025-10-30T02:59:59.000Z')  -- ✅ 23:59 AR = 02:59 UTC (+1 día)
)

SELECT 
  '=== DIAGNÓSTICO PERÍODO AR 26/10 20:00 - 29/10 23:59 ===' AS section,
  NULL AS metric,
  NULL AS value,
  NULL AS percentage

UNION ALL

SELECT 
  'Total Orders',
  'orders_count',
  CAST(COUNT(*) AS STRING),
  '100.0%'
FROM period_orders

UNION ALL

SELECT 
  'Orders con Merchant Info',
  'orders_with_merchant',
  CAST(COUNT(*) AS STRING),
  CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM period_orders), 2), '%')
FROM period_orders
WHERE store_name IS NOT NULL  -- ✅ Cualquier campo merchant sirve

UNION ALL

SELECT 
  'Orders SIN Merchant Info',
  'orders_without_merchant',
  CAST(COUNT(*) AS STRING),
  CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM period_orders), 2), '%')
FROM period_orders
WHERE store_name IS NULL  -- ✅ Sin merchant info

UNION ALL

SELECT 
  '=== STORES ÚNICAS ===',
  NULL,
  NULL,
  NULL

UNION ALL

SELECT 
  'Total Stores Únicas',
  'unique_stores',
  CAST(COUNT(DISTINCT store_id) AS STRING),
  '100.0%'
FROM period_orders

UNION ALL

SELECT 
  'Stores CON Merchant Info',
  'stores_with_merchant',
  CAST(COUNT(DISTINCT store_id) AS STRING),
  CONCAT(ROUND(COUNT(DISTINCT store_id) * 100.0 / (SELECT COUNT(DISTINCT store_id) FROM period_orders), 2), '%')
FROM period_orders
WHERE store_name IS NOT NULL

UNION ALL

SELECT 
  'Stores SIN Merchant Info',
  'stores_without_merchant',
  CAST(COUNT(DISTINCT store_id) AS STRING),
  CONCAT(ROUND(COUNT(DISTINCT store_id) * 100.0 / (SELECT COUNT(DISTINCT store_id) FROM period_orders), 2), '%')
FROM period_orders
WHERE store_name IS NULL

UNION ALL

SELECT 
  '=== VERIFICACIÓN TIMEZONE ===',
  NULL,
  NULL,
  NULL

UNION ALL

SELECT 
  'Primera Order (UTC)',
  'first_order_utc',
  CAST(MIN(completed_at) AS STRING),
  NULL
FROM period_orders

UNION ALL

SELECT 
  'Primera Order (AR Local)',
  'first_order_ar',
  CAST(MIN(from_utc_timestamp(completed_at, 'America/Argentina/Buenos_Aires')) AS STRING),
  NULL
FROM period_orders

UNION ALL

SELECT 
  'Última Order (UTC)',
  'last_order_utc',
  CAST(MAX(completed_at) AS STRING),
  NULL
FROM period_orders

UNION ALL

SELECT 
  'Última Order (AR Local)',
  'last_order_ar',
  CAST(MAX(from_utc_timestamp(completed_at, 'America/Argentina/Buenos_Aires')) AS STRING),
  NULL
FROM period_orders

ORDER BY 
  CASE 
    WHEN section LIKE '===%' THEN 1
    ELSE 2
  END,
  metric
"""


