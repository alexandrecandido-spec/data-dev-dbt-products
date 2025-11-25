-- Quick check of updated KWP testing model

-- 1. Check validation summary
SELECT 
    validation_metric,
    validation_value
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'VALIDATION_SUMMARY'
ORDER BY validation_metric;

-- 2. Check if we have sample data now
SELECT 
    'SAMPLE_DATA_CHECK' as check_type,
    COUNT(*) as sample_records,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    COUNT(DISTINCT country) as countries
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA';

-- 3. Sample of actual data (if any)
SELECT *
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
ORDER BY date DESC
LIMIT 10;
