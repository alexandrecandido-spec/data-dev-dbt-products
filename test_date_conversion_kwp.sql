-- Test date conversion for KWP production table

-- 1. Check raw date formats in production table
SELECT 
    'RAW_DATE_CHECK' as test_type,
    date as original_date_string,
    COUNT(*) as records
FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
GROUP BY date
ORDER BY COUNT(*) DESC
LIMIT 10;

-- 2. Test date conversion logic
SELECT 
    'DATE_CONVERSION_TEST' as test_type,
    date as original_string,
    CASE 
      WHEN date RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 
        TO_DATE(date, 'd/M/yyyy')
      ELSE NULL
    END AS converted_date,
    
    -- Check if conversion worked
    CASE 
      WHEN date RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 
        CASE 
          WHEN TO_DATE(date, 'd/M/yyyy') IS NOT NULL THEN 'SUCCESS'
          ELSE 'FAILED'
        END
      ELSE 'INVALID_FORMAT'
    END AS conversion_status,
    
    COUNT(*) as records

FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
GROUP BY date
ORDER BY records DESC
LIMIT 20;

-- 3. Test date filtering after conversion
SELECT 
    'DATE_FILTER_TEST' as test_type,
    YEAR(
      CASE 
        WHEN date RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 
          TO_DATE(date, 'd/M/yyyy')
        ELSE NULL
      END
    ) as year,
    COUNT(*) as records
FROM data_products_prd.data_manual.ext__marketing__brand_comms__searches_keyword_planner
WHERE 
  CASE 
    WHEN date RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 
      TO_DATE(date, 'd/M/yyyy')
    ELSE NULL
  END IS NOT NULL
  AND 
  CASE 
    WHEN date RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 
      TO_DATE(date, 'd/M/yyyy')
    ELSE NULL
  END >= DATE('2020-01-01')
GROUP BY YEAR(
  CASE 
    WHEN date RLIKE '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 
      TO_DATE(date, 'd/M/yyyy')
    ELSE NULL
  END
)
ORDER BY year DESC;
