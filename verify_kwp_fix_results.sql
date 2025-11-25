-- Quick verification of KWP fix results

-- 1. Check validation metrics now
SELECT 
    validation_metric,
    validation_value
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'VALIDATION_SUMMARY'
  AND validation_metric IN ('TOTAL_RECORDS', 'COUNTRIES', 'TOTAL_SEARCHES_VOLUME')
ORDER BY validation_metric;

-- 2. Quick sample of data
SELECT 
    'DATA_SAMPLE' as check_type,
    date,
    country,
    search_query,
    impressions,
    branded_non_branded,
    is_nuvemshop_tiendanube
FROM data_products_dev.marketing.testing_kwp_sample_all_prod 
WHERE record_type = 'SAMPLE_DATA'
ORDER BY impressions DESC
LIMIT 10;
