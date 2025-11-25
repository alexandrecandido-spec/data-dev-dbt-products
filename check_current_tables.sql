-- Quick check of current tables

-- 1. Goals Silver table
SELECT 'GOALS_SILVER' as table_name, COUNT(*) as records FROM testing_marketing.s__goals__targets_kwp_sc
UNION ALL 
SELECT 'GOLD_MODEL' as table_name, COUNT(*) as records FROM testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp;

-- 2. Goals Silver sample
SELECT 'Goals Silver Sample' as info, date, country, branded_non_branded, expected_impressions 
FROM testing_marketing.s__goals__targets_kwp_sc 
ORDER BY date DESC 
LIMIT 10;

-- 3. Gold Model sample  
SELECT 'Gold Model Sample' as info, date, country, branded_searches_sc, branded_searches_kwp, expected_branded, expected_nonbranded
FROM testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp 
ORDER BY date DESC 
LIMIT 10;
