-- Direct check of KWP silver model

-- 1. Basic stats from silver model
SELECT 
    'SILVER_KWP_STATS' as check_type,
    COUNT(*) as total_records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT search_query) as unique_keywords,
    SUM(impressions) as total_impressions
FROM testing_marketing.s__google_keyword_planner__enriched;

-- 2. Data by year
SELECT 
    YEAR(date) as year,
    COUNT(*) as records,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT search_query) as keywords,
    SUM(impressions) as total_impressions,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM testing_marketing.s__google_keyword_planner__enriched
GROUP BY YEAR(date)
ORDER BY year DESC;

-- 3. Recent sample data
SELECT 
    date,
    country,
    search_query,
    impressions,
    kwp_category,
    branded_non_branded,
    is_nuvemshop_tiendanube
FROM testing_marketing.s__google_keyword_planner__enriched
ORDER BY date DESC
LIMIT 20;

-- 4. Brand detection check
SELECT 
    branded_non_branded,
    is_nuvemshop_tiendanube,
    COUNT(*) as queries,
    SUM(impressions) as total_volume
FROM testing_marketing.s__google_keyword_planner__enriched
GROUP BY branded_non_branded, is_nuvemshop_tiendanube
ORDER BY total_volume DESC;
