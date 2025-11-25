-- =============================================
-- Goals Production Migration Validation  
-- =============================================
-- Verification queries to confirm migration from seed to production table with new structure

-- 1. PRODUCTION SOURCE VERIFICATION - Check raw goals data availability
-- Original table: ext__marketing__brand_comms__marketing_brand_nobrand_daily_goals
SELECT 
    'PRODUCTION_GOALS_SOURCE' as data_source,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(*) as total_records,
    COUNT(DISTINCT country) as countries,
    
    -- New structure verification
    SUM(expected_impressions_brand_exact_sc_daily) as total_branded_sc_goals,
    SUM(expected_market_share_brand_kwp) as total_branded_kwp_goals,
    SUM(expected_searches_non_brand_kwp_daily) as total_nonbranded_kwp_goals,
    
    -- Data quality checks
    COUNT(CASE WHEN expected_impressions_brand_exact_sc_daily > 0 THEN 1 END) as days_with_sc_branded_goals,
    COUNT(CASE WHEN expected_market_share_brand_kwp > 0 THEN 1 END) as days_with_kwp_branded_goals,
    COUNT(CASE WHEN expected_searches_non_brand_kwp_daily > 0 THEN 1 END) as days_with_kwp_nonbranded_goals
-- Note: This would require direct access to production table
-- FROM data_products_prd.data_manual.ext__marketing__brand_comms__marketing_brand_nobrand_daily_goals;

-- 2. SILVER MODEL VERIFICATION - Check processed goals data
SELECT 
    'SILVER_GOALS_MODEL' as data_source,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(*) as total_records,
    COUNT(DISTINCT country) as countries,
    
    -- New specific goal fields
    SUM(expected_branded_sc) as total_branded_sc_goals,
    SUM(expected_branded_kwp) as total_branded_kwp_goals,
    SUM(expected_nonbranded_kwp) as total_nonbranded_kwp_goals,
    
    -- Combined goals (backward compatibility)
    SUM(expected_branded_sc + expected_branded_kwp) as total_branded_combined,
    AVG(expected_branded_sc) as avg_branded_sc_daily,
    AVG(expected_branded_kwp) as avg_branded_kwp_daily,
    AVG(expected_nonbranded_kwp) as avg_nonbranded_kwp_daily
FROM testing_marketing.s__goals__targets_kwp_sc;

-- 3. TESTING MODEL VERIFICATION - Check 2025 goals testing data
SELECT 
    validation_metric,
    validation_value
FROM data_products_dev.marketing.testing_goals_sample_2025_prod 
WHERE record_type = 'VALIDATION_SUMMARY'
ORDER BY validation_metric;

-- 4. GOALS STRUCTURE COMPARISON - Old vs New
SELECT 
    'STRUCTURE_COMPARISON' as check_type,
    'Old: Single expected_impressions field with search_type (branded/nonbranded)' as old_structure,
    'New: 3 specific fields - expected_branded_sc, expected_branded_kwp, expected_nonbranded_kwp' as new_structure,
    'Benefit: More granular goals by data source and type' as improvement;

-- 5. GOLD MODEL VERIFICATION - Check goals integration in performance model
SELECT 
    'GOLD_MODEL_GOALS_DATA' as check_type,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    
    -- Combined goals (backward compatibility maintained)
    SUM(expected_branded) as total_expected_branded,
    SUM(expected_nonbranded) as total_expected_nonbranded,
    
    -- New specific goals (additional granularity)
    SUM(expected_branded_sc) as total_expected_branded_sc,
    SUM(expected_branded_kwp) as total_expected_branded_kwp,
    SUM(expected_nonbranded_kwp) as total_expected_nonbranded_kwp,
    
    -- Data coverage
    COUNT(CASE WHEN has_goal_data THEN 1 END) as days_with_goal_data,
    COUNT(*) as total_days
FROM testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp;

-- 6. GOALS BY COUNTRY AND TYPE - Detailed breakdown
SELECT 
    country,
    
    -- Specific goal types
    SUM(expected_branded_sc) as sc_branded_goals,
    SUM(expected_branded_kwp) as kwp_branded_goals,
    SUM(expected_nonbranded_kwp) as kwp_nonbranded_goals,
    
    -- Daily averages
    AVG(expected_branded_sc) as avg_daily_sc_branded,
    AVG(expected_branded_kwp) as avg_daily_kwp_branded,
    AVG(expected_nonbranded_kwp) as avg_daily_kwp_nonbranded,
    
    COUNT(*) as total_days
FROM testing_marketing.s__goals__targets_kwp_sc
GROUP BY country
ORDER BY country;

-- 7. DATA QUALITY VALIDATION - Check goal values
SELECT 
    'DATA_QUALITY_CHECK' as check_type,
    country,
    
    -- Quality metrics
    COUNT(CASE WHEN expected_branded_sc > 0 AND expected_branded_kwp > 0 AND expected_nonbranded_kwp > 0 
               THEN 1 END) as days_with_all_goals,
    COUNT(CASE WHEN expected_branded_sc <= 0 AND expected_branded_kwp <= 0 AND expected_nonbranded_kwp <= 0 
               THEN 1 END) as days_with_no_goals,
    COUNT(*) as total_days,
    
    -- Goal ranges
    MIN(expected_branded_sc + expected_branded_kwp + expected_nonbranded_kwp) as min_total_goals,
    MAX(expected_branded_sc + expected_branded_kwp + expected_nonbranded_kwp) as max_total_goals,
    AVG(expected_branded_sc + expected_branded_kwp + expected_nonbranded_kwp) as avg_total_goals
    
FROM testing_marketing.s__goals__targets_kwp_sc
GROUP BY country
ORDER BY country;

-- 8. TESTING MODEL CLASSIFICATION VERIFICATION
SELECT 
    classification_type,
    COUNT(*) as records,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage,
    
    -- Average goals by classification type
    AVG(expected_branded_sc) as avg_sc_goals,
    AVG(expected_branded_kwp) as avg_kwp_branded_goals,
    AVG(expected_nonbranded_kwp) as avg_kwp_nonbranded_goals
FROM data_products_dev.marketing.testing_goals_sample_2025_prod 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY classification_type
ORDER BY records DESC;
