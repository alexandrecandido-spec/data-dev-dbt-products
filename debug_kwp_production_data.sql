-- =============================================
-- Debug KWP Production Data - Check what's available
-- =============================================

-- 1. Check if production table has any data at all
SELECT 
    'PRODUCTION_RAW_CHECK' as check_type,
    COUNT(*) as total_records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT keyword) as unique_keywords
FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
LIMIT 1;

-- 2. Check date distribution in production table
SELECT 
    YEAR(date) as year,
    COUNT(*) as records,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT keyword) as keywords,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
GROUP BY YEAR(date)
ORDER BY year DESC;

-- 3. Check our silver model - is it getting any data?
SELECT 
    'SILVER_MODEL_CHECK' as check_type,
    COUNT(*) as total_records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(DISTINCT country) as countries
FROM testing_marketing.s__google_keyword_planner__enriched
LIMIT 1;

-- 4. Check silver model by year
SELECT 
    YEAR(date) as year,
    COUNT(*) as records,
    COUNT(DISTINCT country) as countries,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM testing_marketing.s__google_keyword_planner__enriched
GROUP BY YEAR(date)
ORDER BY year DESC;

-- 5. Sample of recent data from silver model (if any)
SELECT *
FROM testing_marketing.s__google_keyword_planner__enriched
ORDER BY date DESC
LIMIT 10;
