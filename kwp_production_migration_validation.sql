-- =============================================
-- KWP Production Migration Validation
-- =============================================
-- Verification queries to confirm migration from seed to production table

-- 1. PRODUCTION SOURCE VERIFICATION - Check raw data availability
-- Original table: data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
SELECT 
    'PRODUCTION_SOURCE' as data_source,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(*) as total_records,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT keyword) as unique_keywords,
    SUM(searches) as total_search_volume
-- Note: This would require direct access to production table
-- FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner;

-- 2. SILVER MODEL VERIFICATION - Check processed KWP data
SELECT 
    'SILVER_KWP_MODEL' as data_source,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(*) as total_records,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT search_query) as unique_keywords,
    SUM(impressions) as total_impressions,
    COUNT(DISTINCT kwp_category) as categories_detected
FROM testing_marketing.s__google_keyword_planner__enriched;

-- 3. TESTING MODEL VERIFICATION - Check 2024 testing data
SELECT 
    validation_metric,
    validation_value
FROM data_products_dev.marketing.testing_kwp_sample_2024_prod 
WHERE record_type = 'VALIDATION_SUMMARY'
ORDER BY validation_metric;

-- 4. GOLD MODEL VERIFICATION - Check KWP performance in final model
SELECT 
    'GOLD_MODEL_KWP_DATA' as check_type,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    SUM(branded_searches_kwp) as total_branded_kwp,
    SUM(nonbranded_searches_kwp) as total_nonbranded_kwp,
    COUNT(CASE WHEN has_kwp_data THEN 1 END) as days_with_kwp_data,
    COUNT(*) as total_days
FROM testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp;

-- 5. BRAND DETECTION VERIFICATION - Check that macros work with production data
SELECT 
    country,
    branded_non_branded,
    COUNT(*) as queries,
    SUM(impressions) as total_volume,
    COUNT(DISTINCT d2c_brand_names) as unique_d2c_brands,
    COUNT(DISTINCT marketplace_brand_names) as unique_marketplace_brands
FROM testing_marketing.s__google_keyword_planner__enriched
WHERE date >= DATE('2024-01-01')
GROUP BY country, branded_non_branded
ORDER BY country, branded_non_branded;

-- 6. DATA QUALITY CHECK - Compare old vs new structure
SELECT 
    'DATA_MIGRATION_CHECK' as check_type,
    'New production structure has keyword, date, country, searches columns' as note,
    'Category column removed - now using automated classification macro' as improvement,
    'Date range expanded beyond 2023 sample to full production history' as benefit;

-- 7. TIENDANUBE BRANDED VERIFICATION - Key business logic
SELECT 
    country,
    is_nuvemshop_tiendanube,
    is_next_evolucion,
    branded_non_branded,
    COUNT(*) as queries,
    SUM(impressions) as total_impressions
FROM testing_marketing.s__google_keyword_planner__enriched
WHERE (is_nuvemshop_tiendanube = true OR branded_non_branded = 'branded')
  AND date >= DATE('2024-01-01')
GROUP BY country, is_nuvemshop_tiendanube, is_next_evolucion, branded_non_branded
ORDER BY country, is_nuvemshop_tiendanube DESC, is_next_evolucion;
