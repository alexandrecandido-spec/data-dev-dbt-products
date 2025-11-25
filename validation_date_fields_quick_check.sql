-- Validación rápida de campos de fecha
SELECT 
    date,
    date_day,
    date_month,
    date_quarter,
    date_week,
    date_year,
    COUNT(*) as records
FROM data_products_dev.testing_marketing.testing_gsc_sample_oct2025 
WHERE record_type = 'SAMPLE_DATA'
GROUP BY date, date_day, date_month, date_quarter, date_week, date_year
ORDER BY date
LIMIT 5;
