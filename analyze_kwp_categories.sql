-- =============================================
-- Análisis de Categories en KWP para crear macro automática
-- =============================================

-- 1. ANÁLISIS POR CATEGORÍA Y PAÍS
SELECT 
    kwp_category,
    country,
    COUNT(*) as keyword_count,
    COUNT(DISTINCT search_query) as unique_keywords,
    SUM(impressions) as total_volume
FROM data_products_dev.testing_marketing.testing_kwp_sample_2023_v2 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY kwp_category, country
ORDER BY kwp_category, country;

-- 2. EJEMPLOS DE KEYWORDS POR CATEGORÍA
SELECT 
    kwp_category,
    country,
    search_query,
    SUM(impressions) as total_volume
FROM data_products_dev.testing_marketing.testing_kwp_sample_2023_v2 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY kwp_category, country, search_query
ORDER BY kwp_category, country, total_volume DESC;

-- 3. CATEGORÍAS MÁS COMUNES
SELECT 
    kwp_category,
    COUNT(DISTINCT search_query) as unique_keywords,
    COUNT(*) as total_records,
    SUM(impressions) as total_volume,
    AVG(impressions) as avg_volume
FROM data_products_dev.testing_marketing.testing_kwp_sample_2023_v2 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY kwp_category
ORDER BY total_volume DESC;

-- 4. ANÁLISIS DE PATTERNS ESPECÍFICOS
-- Branded terms
SELECT 
    'BRANDED_ANALYSIS' as analysis_type,
    kwp_category,
    search_query,
    country,
    SUM(impressions) as volume
FROM data_products_dev.testing_marketing.testing_kwp_sample_2023_v2 
WHERE record_type = 'SAMPLE_DATA'
  AND kwp_category = 'Branded'
GROUP BY kwp_category, search_query, country
ORDER BY volume DESC
LIMIT 50;

-- 5. E-commerce/DTC terms
SELECT 
    'ECOMMERCE_ANALYSIS' as analysis_type,
    kwp_category,
    search_query,
    country,
    SUM(impressions) as volume
FROM data_products_dev.testing_marketing.testing_kwp_sample_2023_v2 
WHERE record_type = 'SAMPLE_DATA'
  AND kwp_category IN ('E-commerce', 'Ecommerce', 'DTC')
GROUP BY kwp_category, search_query, country
ORDER BY volume DESC
LIMIT 50;

-- 6. Marketplace terms  
SELECT 
    'MARKETPLACE_ANALYSIS' as analysis_type,
    kwp_category,
    search_query,
    country,
    SUM(impressions) as volume
FROM data_products_dev.testing_marketing.testing_kwp_sample_2023_v2 
WHERE record_type = 'SAMPLE_DATA'
  AND kwp_category = 'Marketplace'
GROUP BY kwp_category, search_query, country
ORDER BY volume DESC
LIMIT 50;
