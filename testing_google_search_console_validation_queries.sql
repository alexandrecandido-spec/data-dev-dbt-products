-- =============================================
-- Google Search Console Testing Validation Queries
-- =============================================
-- Use these queries to validate the testing table results

-- 0. DATE FIELDS VALIDATION - Check if date dimensions are working correctly
SELECT 
    date,
    date_day,
    date_month,
    date_quarter,
    date_week,
    date_year,
    COUNT(*) as records
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY date, date_day, date_month, date_quarter, date_week, date_year
ORDER BY date
LIMIT 10;

-- 1. VALIDATION SUMMARY - Check overall metrics
SELECT 
    validation_metric,
    validation_value,
    testing_created_at
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'VALIDATION_SUMMARY'
ORDER BY validation_metric;

-- 2. DATA QUALITY CHECKS - Find any errors
SELECT 
    data_quality_check,
    COUNT(*) as record_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY data_quality_check
ORDER BY record_count DESC;

-- 3. BRAND DETECTION VALIDATION - Check brand detection results
SELECT 
    country,
    classification_type,
    COUNT(*) as queries,
    COUNT(DISTINCT d2c_brand_names) as unique_d2c_brands,
    COUNT(DISTINCT marketplace_brand_names) as unique_marketplace_brands
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY country, classification_type
ORDER BY country, queries DESC;

-- 4. TIENDANUBE DETECTION - Validate our brand monitoring
SELECT 
    country,
    is_nuvemshop_tiendanube,
    is_next_evolucion,
    COUNT(*) as queries,
    SUM(impressions) as total_impressions
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY country, is_nuvemshop_tiendanube, is_next_evolucion
ORDER BY country, total_impressions DESC;

-- 5. NON-BRANDED INTENT ANALYSIS - Check intent classification
SELECT 
    non_brand_category,
    COUNT(*) as queries,
    COUNT(DISTINCT non_brand_term) as unique_terms,
    SUM(impressions) as total_impressions,
    AVG(click_through_rate) as avg_ctr
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA' 
  AND branded_non_branded = 'nonbranded'
  AND non_brand_category IS NOT NULL
GROUP BY non_brand_category
ORDER BY total_impressions DESC;

-- 6. TOP D2C COMPETITORS - Check D2C brand detection
SELECT 
    country,
    d2c_brand_names,
    d2c_match_type,
    COUNT(*) as queries,
    SUM(impressions) as total_impressions,
    AVG(click_through_rate) as avg_ctr
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA' 
  AND d2c_brand_names IS NOT NULL
GROUP BY country, d2c_brand_names, d2c_match_type
ORDER BY country, total_impressions DESC
LIMIT 20;

-- 7. TOP MARKETPLACE COMPETITORS - Check marketplace detection
SELECT 
    country,
    marketplace_brand_names,
    marketplace_match_type,
    COUNT(*) as queries,
    SUM(impressions) as total_impressions,
    AVG(click_through_rate) as avg_ctr
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA' 
  AND marketplace_brand_names IS NOT NULL
GROUP BY country, marketplace_brand_names, marketplace_match_type
ORDER BY country, total_impressions DESC
LIMIT 20;

-- 8. SAMPLE SEARCH QUERIES - Inspect actual queries for manual validation
SELECT 
    country,
    search_query,
    branded_non_branded,
    d2c_brand_names,
    marketplace_brand_names,
    non_brand_category,
    is_nuvemshop_tiendanube,
    impressions,
    clicks
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA'
ORDER BY impressions DESC
LIMIT 50;

-- 9. EDGE CASES - Look for interesting patterns
SELECT 
    'Both D2C and Marketplace' as case_type,
    COUNT(*) as count
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA' 
  AND d2c_brand_names IS NOT NULL 
  AND marketplace_brand_names IS NOT NULL

UNION ALL

SELECT 
    'Tiendanube detected in' || country as case_type,
    COUNT(*) as count
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA' 
  AND is_nuvemshop_tiendanube = true
GROUP BY country

UNION ALL

SELECT 
    'Next Evolution queries' as case_type,
    COUNT(*) as count
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA' 
  AND is_next_evolucion = true;

-- 10. MATCH TYPE DISTRIBUTION - Check exact vs broad matches
SELECT 
    'D2C Brands' as brand_type,
    d2c_match_type as match_type,
    COUNT(*) as queries,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY 'D2C') as percentage
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA' AND d2c_match_type IS NOT NULL
GROUP BY d2c_match_type

UNION ALL

SELECT 
    'Marketplace Brands' as brand_type,
    marketplace_match_type as match_type,
    COUNT(*) as queries,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY 'Marketplace') as percentage
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA' AND marketplace_match_type IS NOT NULL
GROUP BY marketplace_match_type

ORDER BY brand_type, match_type;
