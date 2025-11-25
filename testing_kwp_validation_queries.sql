-- =============================================
-- Google Keyword Planner Testing Validation Queries
-- =============================================
-- Use these queries to validate the KWP testing table results

-- 0. DATE FIELDS VALIDATION - Check if date dimensions are working correctly
SELECT 
    date,
    date_day,
    date_month,
    date_quarter,
    date_week,
    date_year,
    date_day_of_week,
    COUNT(*) as records
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY date, date_day, date_month, date_quarter, date_week, date_year, date_day_of_week
ORDER BY date
LIMIT 10;

-- 1. VALIDATION SUMMARY - Check overall metrics
SELECT 
    validation_metric,
    validation_value,
    testing_created_at
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'VALIDATION_SUMMARY'
ORDER BY validation_metric;

-- 2. DATA QUALITY CHECKS - Find any errors
SELECT 
    data_quality_check,
    COUNT(*) as record_count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY data_quality_check
ORDER BY record_count DESC;

-- 3. BRAND DETECTION VALIDATION - Check brand detection results
SELECT 
    country,
    classification_type,
    COUNT(*) as queries,
    COUNT(DISTINCT d2c_brand_names) as unique_d2c_brands,
    COUNT(DISTINCT marketplace_brand_names) as unique_marketplace_brands,
    SUM(impressions) as total_search_volume
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY country, classification_type
ORDER BY country, total_search_volume DESC;

-- 4. TIENDANUBE/NUVEMSHOP ANALYSIS - Check our brand detection
SELECT 
    country,
    is_nuvemshop_tiendanube,
    is_next_evolucion,
    COUNT(*) as queries,
    SUM(impressions) as total_volume,
    AVG(impressions) as avg_volume_per_query
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
  AND (d2c_brand_names = 'tiendanube' OR d2c_brand_names = 'nuvemshop' OR is_nuvemshop_tiendanube = true)
GROUP BY country, is_nuvemshop_tiendanube, is_next_evolucion
ORDER BY country, total_volume DESC;

-- 5. OFFICIAL FLAGS VALIDATION - Check official brand flags
SELECT 
    country,
    flag_d2c_oficial,
    flag_marketplace_oficial,
    COUNT(*) as queries,
    SUM(impressions) as total_volume,
    COUNT(DISTINCT d2c_brand_names) as unique_d2c_brands,
    COUNT(DISTINCT marketplace_brand_names) as unique_marketplace_brands
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
  AND (d2c_brand_names IS NOT NULL OR marketplace_brand_names IS NOT NULL)
GROUP BY country, flag_d2c_oficial, flag_marketplace_oficial
ORDER BY country, total_volume DESC;

-- 6. NONBRANDED TERMS ANALYSIS - Check nonbranded classification
SELECT 
    non_brand_category,
    non_brand_match_type,
    COUNT(*) as queries,
    SUM(impressions) as total_volume,
    COUNT(DISTINCT non_brand_term) as unique_terms,
    AVG(impressions) as avg_volume
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
  AND branded_non_branded = 'nonbranded'
  AND non_brand_category IS NOT NULL
GROUP BY non_brand_category, non_brand_match_type
ORDER BY total_volume DESC;

-- 7. COMPARISON WITH ORIGINAL KWP CATEGORY - Check how our classification differs
SELECT 
    kwp_category as original_category,
    branded_non_branded as our_classification,
    COUNT(*) as queries,
    SUM(impressions) as total_volume,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage_of_total
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY kwp_category, branded_non_branded
ORDER BY total_volume DESC;

-- 8. TOP BRANDED QUERIES BY VOLUME
SELECT 
    country,
    search_query,
    d2c_brand_names,
    marketplace_brand_names,
    d2c_match_type,
    marketplace_match_type,
    flag_d2c_oficial,
    flag_marketplace_oficial,
    SUM(impressions) as total_volume
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
  AND branded_non_branded = 'branded'
GROUP BY country, search_query, d2c_brand_names, marketplace_brand_names, 
         d2c_match_type, marketplace_match_type, flag_d2c_oficial, flag_marketplace_oficial
ORDER BY total_volume DESC
LIMIT 20;

-- 9. NON-ACQUISITION TERMS ANALYSIS
SELECT 
    country,
    is_nuvemshop_tiendanube,
    is_non_adquisition_term,
    non_adquisition_terms,
    COUNT(*) as queries,
    SUM(impressions) as total_volume
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
  AND is_nuvemshop_tiendanube = true
GROUP BY country, is_nuvemshop_tiendanube, is_non_adquisition_term, non_adquisition_terms
ORDER BY total_volume DESC;

-- 10. MONTHLY TREND ANALYSIS - Check data distribution over time
SELECT 
    date_month,
    country,
    branded_non_branded,
    COUNT(*) as queries,
    SUM(impressions) as total_volume,
    COUNT(DISTINCT search_query) as unique_queries
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY date_month, country, branded_non_branded
ORDER BY date_month, country, branded_non_branded;
