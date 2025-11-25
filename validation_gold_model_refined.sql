-- =============================================
-- Validación del Modelo Gold Refinado
-- =============================================

-- 1. ESTRUCTURA GENERAL - Mostrar campos y primeros registros
SELECT 
    date,
    date_day,
    date_month, 
    date_quarter,
    date_week,
    date_year,
    date_day_of_week,
    country,
    
    -- Search Console Performance
    branded_searches_sc,
    branded_clicks_sc,
    branded_ctr_sc,
    nonbranded_searches_sc,
    nonbranded_clicks_sc,
    nonbranded_ctr_sc,
    
    -- KWP Performance  
    branded_searches_kwp,
    nonbranded_searches_kwp,
    
    -- Goals
    expected_branded,
    expected_nonbranded,
    
    -- Data flags
    has_search_console_data,
    has_kwp_data,
    has_goal_data,
    
    created_at
FROM data_products_dev.testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp
ORDER BY date DESC, country
LIMIT 10;

-- 2. RESUMEN POR PAÍS - Performance agregada
SELECT 
    country,
    COUNT(*) as total_days,
    
    -- Search Console totals
    SUM(branded_searches_sc) as total_branded_sc,
    SUM(branded_clicks_sc) as total_branded_clicks_sc,
    AVG(branded_ctr_sc) as avg_branded_ctr_sc,
    SUM(nonbranded_searches_sc) as total_nonbranded_sc,
    
    -- KWP totals
    SUM(branded_searches_kwp) as total_branded_kwp,
    SUM(nonbranded_searches_kwp) as total_nonbranded_kwp,
    
    -- Goals totals
    SUM(expected_branded) as total_expected_branded,
    SUM(expected_nonbranded) as total_expected_nonbranded,
    
    -- Data coverage
    SUM(CASE WHEN has_search_console_data THEN 1 ELSE 0 END) as days_with_sc_data,
    SUM(CASE WHEN has_kwp_data THEN 1 ELSE 0 END) as days_with_kwp_data,
    SUM(CASE WHEN has_goal_data THEN 1 ELSE 0 END) as days_with_goal_data
    
FROM data_products_dev.testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp
GROUP BY country
ORDER BY country;

-- 3. VALIDACIÓN LÓGICA - Verificar criterios específicos
SELECT 
    'Branded Logic Validation' as check_type,
    country,
    date,
    branded_searches_sc,
    branded_searches_kwp,
    expected_branded,
    CASE 
        WHEN branded_searches_sc > 0 THEN 'SC has Tiendanube/Nuvemshop exact (no evolution/next)'
        ELSE 'No SC branded data'
    END as sc_branded_check,
    CASE 
        WHEN branded_searches_kwp > 0 THEN 'KWP has Tiendanube/Nuvemshop exact (no evolution/next)'  
        ELSE 'No KWP branded data'
    END as kwp_branded_check
FROM data_products_dev.testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp
WHERE (branded_searches_sc > 0 OR branded_searches_kwp > 0)
ORDER BY date DESC, country
LIMIT 20;

-- 4. COBERTURA DE DATOS POR MES
SELECT 
    date_month,
    country,
    COUNT(*) as days_in_month,
    SUM(CASE WHEN has_search_console_data THEN 1 ELSE 0 END) as days_with_sc,
    SUM(CASE WHEN has_kwp_data THEN 1 ELSE 0 END) as days_with_kwp,  
    SUM(CASE WHEN has_goal_data THEN 1 ELSE 0 END) as days_with_goals,
    
    -- Performance summary
    SUM(branded_searches_sc + branded_searches_kwp) as total_branded_searches,
    SUM(nonbranded_searches_sc + nonbranded_searches_kwp) as total_nonbranded_searches,
    SUM(expected_branded + expected_nonbranded) as total_expected
    
FROM data_products_dev.testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp
GROUP BY date_month, country
ORDER BY date_month DESC, country;

-- 5. ANÁLISIS CTR - Solo Search Console tiene clicks
SELECT 
    country,
    AVG(branded_ctr_sc) as avg_branded_ctr,
    AVG(nonbranded_ctr_sc) as avg_nonbranded_ctr,
    COUNT(CASE WHEN branded_ctr_sc IS NOT NULL THEN 1 END) as days_with_branded_ctr,
    COUNT(CASE WHEN nonbranded_ctr_sc IS NOT NULL THEN 1 END) as days_with_nonbranded_ctr
FROM data_products_dev.testing_marketing.g__brand_nonbrand_performance__daily_summary__sc__kwp
WHERE has_search_console_data = true
GROUP BY country
ORDER BY country;
