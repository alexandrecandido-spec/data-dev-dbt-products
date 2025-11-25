-- 🔍 REPORTE DIAGNÓSTICO: Orders y Stores con/sin merchant info
-- Período: 2025-10-26T20:00:00.000Z a 2025-10-29T23:59:59.000Z (UTC)

diagnostic_report_sql = """
SELECT 
  '=== DIAGNÓSTICO GENERAL ===' AS section,
  NULL AS metric,
  NULL AS value,
  NULL AS percentage

UNION ALL

SELECT 
  'Total Orders',
  'orders_count',
  CAST(COUNT(*) AS STRING),
  '100.0%'
FROM orders_scoped 
WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
  AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')

UNION ALL

SELECT 
  'Orders con Merchant Info',
  'orders_with_merchant',
  CAST(COUNT(*) AS STRING),
  CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders_scoped 
    WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
      AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')), 2), '%')
FROM orders_scoped 
WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
  AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')
  AND store_name IS NOT NULL  -- ✅ Cualquier campo merchant sirve

UNION ALL

SELECT 
  'Orders SIN Merchant Info',
  'orders_without_merchant',
  CAST(COUNT(*) AS STRING),
  CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders_scoped 
    WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
      AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')), 2), '%')
FROM orders_scoped 
WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
  AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')
  AND store_name IS NULL  -- ✅ Sin merchant info

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
FROM orders_scoped 
WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
  AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')

UNION ALL

SELECT 
  'Stores CON Merchant Info',
  'stores_with_merchant',
  CAST(COUNT(DISTINCT store_id) AS STRING),
  CONCAT(ROUND(COUNT(DISTINCT store_id) * 100.0 / (SELECT COUNT(DISTINCT store_id) FROM orders_scoped 
    WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
      AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')), 2), '%')
FROM orders_scoped 
WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
  AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')
  AND store_name IS NOT NULL

UNION ALL

SELECT 
  'Stores SIN Merchant Info',
  'stores_without_merchant',
  CAST(COUNT(DISTINCT store_id) AS STRING),
  CONCAT(ROUND(COUNT(DISTINCT store_id) * 100.0 / (SELECT COUNT(DISTINCT store_id) FROM orders_scoped 
    WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
      AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')), 2), '%')
FROM orders_scoped 
WHERE completed_at >= TIMESTAMP('2025-10-26T20:00:00.000Z')
  AND completed_at <= TIMESTAMP('2025-10-29T23:59:59.000Z')
  AND store_name IS NULL

ORDER BY 
  CASE 
    WHEN section LIKE '===%' THEN 1
    ELSE 2
  END,
  metric
"""

# Ejecutar diagnóstico
diagnostic_df = spark.sql(diagnostic_report_sql)
diagnostic_df.show(20, False)

print("🔍 INTERPRETACIÓN:")
print("- Si 'Orders SIN Merchant Info' > 0% → Recuperaremos orders con LEFT JOIN")
print("- Si 'Stores SIN Merchant Info' > 0% → Algunas stores no están en merchant_complete")
print("- Si ambos = 0% → El INNER JOIN actual está bien")


