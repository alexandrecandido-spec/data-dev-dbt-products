-- =============================================
-- VERIFICACIÓN: Clasificación corregida de "wix" en KWP
-- =============================================

-- 1. VERIFICACIÓN ESPECÍFICA DE "WIX"
SELECT 
  'WIX_CLASSIFICATION_CHECK' AS verification_type,
  search_query,
  country,
  kwp_category,              -- ← Ahora debería ser 'Branded'
  d2c_brand_names,          -- ← Debería detectar 'wix'
  marketplace_brand_names,   -- ← NULL
  branded_non_branded,      -- ← 'branded'
  flag_d2c_oficial         -- ← false (no oficial pero sí brand)
FROM data_products_dev.testing_marketing.testing_kwp_sample_all_prod
WHERE record_type = 'SAMPLE_DATA'
  AND CONTAINS(LOWER(search_query), 'wix')
ORDER BY country, search_query
LIMIT 20;

-- 2. RESUMEN DE CLASIFICACIONES KWP_CATEGORY
SELECT 
  'KWP_CATEGORY_SUMMARY' AS verification_type,
  kwp_category,
  COUNT(*) AS queries_count,
  COUNT(DISTINCT search_query) AS unique_queries,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM data_products_dev.testing_marketing.testing_kwp_sample_all_prod
WHERE record_type = 'SAMPLE_DATA'
GROUP BY kwp_category
ORDER BY queries_count DESC;

-- 3. VALIDAR CONSISTENCIA: Branded queries deben tener kwp_category = 'Branded'
SELECT 
  'CONSISTENCY_CHECK' AS verification_type,
  branded_non_branded,
  kwp_category,
  COUNT(*) AS queries_count,
  CASE 
    WHEN branded_non_branded = 'branded' AND kwp_category != 'Branded' THEN '❌ INCONSISTENCIA'
    WHEN branded_non_branded = 'nonbranded' AND kwp_category = 'Branded' THEN '❌ INCONSISTENCIA' 
    ELSE '✅ CONSISTENTE'
  END AS consistency_status
FROM data_products_dev.testing_marketing.testing_kwp_sample_all_prod
WHERE record_type = 'SAMPLE_DATA'
GROUP BY branded_non_branded, kwp_category
ORDER BY branded_non_branded, kwp_category;

-- 4. OTROS BRANDS D2C DETECTADOS (para revisar si hay más problemas)
SELECT 
  'D2C_BRANDS_SAMPLE' AS verification_type,
  d2c_brand_names AS detected_brand,
  kwp_category,
  COUNT(*) AS queries_count,
  COUNT(DISTINCT search_query) AS unique_queries
FROM data_products_dev.testing_marketing.testing_kwp_sample_all_prod
WHERE record_type = 'SAMPLE_DATA'
  AND d2c_brand_names IS NOT NULL
  AND d2c_brand_names != ''
GROUP BY d2c_brand_names, kwp_category
ORDER BY queries_count DESC
LIMIT 15;

-- 5. VALIDATION METRICS ACTUALIZADAS
SELECT 
  'UPDATED_VALIDATION_METRICS' AS verification_type,
  validation_metric,
  validation_value
FROM data_products_dev.testing_marketing.testing_kwp_sample_all_prod
WHERE record_type = 'VALIDATION_SUMMARY'
  AND validation_metric IN ('TOTAL_RECORDS', 'BRANDED_QUERIES', 'D2C_BRANDS_DETECTED')
ORDER BY validation_metric;
