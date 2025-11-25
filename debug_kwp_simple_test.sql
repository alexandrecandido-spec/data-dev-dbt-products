-- =============================================
-- Simple KWP Production Connection Test
-- =============================================

-- Test 1: Can we access the production table at all?
SELECT 
    'BASIC_CONNECTION_TEST' as test_type,
    COUNT(*) as records_available
FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
LIMIT 1;

-- Test 2: What's the actual data structure and sample?
SELECT 
    'SAMPLE_DATA' as test_type,
    keyword,
    date,
    country,
    searches,
    YEAR(date) as year,
    MONTH(date) as month
FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
ORDER BY date DESC
LIMIT 20;
