-- =============================================
-- Quick Validation Queries for Testing Tables
-- =============================================

-- 1. GOALS TESTING - Validation Summary (NEW PRODUCTION STRUCTURE)
SELECT 
    validation_metric,
    validation_value,
    testing_created_at
FROM data_products_dev.marketing.testing_goals_sample_2025_prod 
WHERE record_type = 'VALIDATION_SUMMARY'
ORDER BY validation_metric;

-- 2. GOALS TESTING - Sample Data Quality (NEW STRUCTURE)
SELECT 
    data_quality_check,
    classification_type,
    COUNT(*) as records,
    SUM(expected_branded_sc + expected_branded_kwp + expected_nonbranded_kwp) as total_expected
FROM data_products_dev.marketing.testing_goals_sample_2025_prod 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY data_quality_check, classification_type
ORDER BY data_quality_check, classification_type;

-- 3. GOALS TESTING - By Country and Specific Goal Types (NEW STRUCTURE)
SELECT 
    country,
    COUNT(*) as days,
    SUM(expected_branded_sc) as total_sc_branded_goals,
    SUM(expected_branded_kwp) as total_kwp_branded_goals,
    SUM(expected_nonbranded_kwp) as total_kwp_nonbranded_goals,
    AVG(expected_branded_sc) as avg_daily_sc_branded,
    AVG(expected_branded_kwp) as avg_daily_kwp_branded,
    AVG(expected_nonbranded_kwp) as avg_daily_kwp_nonbranded
FROM data_products_dev.marketing.testing_goals_sample_2025_prod 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY country
ORDER BY country;

-- 4. GOLD TESTING - Validation Summary
SELECT 
    validation_metric,
    validation_value,
    testing_created_at
FROM data_products_dev.testing_marketing.testing_gold_performance_2025 
WHERE record_type = 'VALIDATION_SUMMARY'
ORDER BY validation_metric;

-- 5. GOLD TESTING - Data Coverage Analysis
SELECT 
    data_coverage_type,
    COUNT(*) as records,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM data_products_dev.testing_marketing.testing_gold_performance_2025 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY data_coverage_type
ORDER BY records DESC;

-- 6. GOLD TESTING - Performance by Country
SELECT 
    country,
    
    -- Search Console totals
    SUM(branded_searches_sc) as total_branded_sc,
    SUM(nonbranded_searches_sc) as total_nonbranded_sc,
    
    -- KWP totals  
    SUM(branded_searches_kwp) as total_branded_kwp,
    SUM(nonbranded_searches_kwp) as total_nonbranded_kwp,
    
    -- Goals totals
    SUM(expected_branded) as total_expected_branded,
    SUM(expected_nonbranded) as total_expected_nonbranded,
    
    -- Data coverage
    SUM(CASE WHEN has_search_console_data THEN 1 ELSE 0 END) as days_with_sc,
    SUM(CASE WHEN has_kwp_data THEN 1 ELSE 0 END) as days_with_kwp,
    SUM(CASE WHEN has_goal_data THEN 1 ELSE 0 END) as days_with_goals,
    
    COUNT(*) as total_days
    
FROM data_products_dev.testing_marketing.testing_gold_performance_2025 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY country
ORDER BY country;

-- 7. GOLD TESTING - Recent Performance Sample
SELECT 
    date,
    country,
    branded_searches_sc,
    branded_searches_kwp,
    expected_branded,
    branded_performance_vs_goal_pct,
    nonbranded_searches_sc + nonbranded_searches_kwp as total_nonbranded_actual,
    expected_nonbranded,
    data_coverage_type
FROM data_products_dev.testing_marketing.testing_gold_performance_2025 
WHERE record_type = 'SAMPLE_DATA'
  AND date >= DATE('2025-01-01')
ORDER BY date DESC, country
LIMIT 20;

-- 8. TIENDANUBE BRANDED LOGIC VALIDATION
-- Verify we're getting the right branded searches (Tiendanube exact, no evolution/next)
SELECT 
    'Branded Logic Check' as check_type,
    country,
    SUM(branded_searches_sc) as sc_branded_impressions,
    SUM(branded_searches_kwp) as kwp_branded_impressions,
    SUM(expected_branded) as expected_branded_impressions,
    COUNT(*) as days_analyzed
FROM data_products_dev.testing_marketing.testing_gold_performance_2025 
WHERE record_type = 'SAMPLE_DATA'
  AND (branded_searches_sc > 0 OR branded_searches_kwp > 0 OR expected_branded > 0)
GROUP BY country
ORDER BY country;
