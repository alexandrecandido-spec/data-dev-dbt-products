-- Query adaptada de Redshift a Databricks usando vertifier en lugar de type
-- Análisis de GMV, órdenes y ticket promedio por vertical basado en vertifier

WITH 
-- Obtener el vertifier más reciente por tienda (fallback)
latest_vertifier AS (
    SELECT 
        store_id,
        CASE 
            WHEN vertifier IS NULL THEN 'Not Informed'
            WHEN vertifier IN ('', 'unknown') THEN 'Not Informed'
            ELSE vertifier 
        END AS vertifier_classification
    FROM (
        SELECT 
            CAST(storeid AS BIGINT) AS store_id,
            CAST(primary.name AS STRING) AS vertifier,
            ROW_NUMBER() OVER(PARTITION BY storeid ORDER BY createdat DESC) AS rnk
        FROM hive_metastore.antifraud_service.vertifier_store_inferences
    ) WHERE rnk = 1
),

-- Combinando store_settings.type (prioridad) con vertifier (fallback)
-- Replica la lógica de dbt: CASE WHEN s.type IS NULL THEN v.vertifier ELSE s.type END
store_classification AS (
    SELECT 
        s.store_id,
        CASE 
            WHEN s.type IS NULL THEN v.vertifier_classification 
            ELSE s.type 
        END AS final_classification
    FROM hive_metastore.moltres.mwp_store_settings s
    LEFT JOIN latest_vertifier v ON v.store_id = s.store_id
),

-- Tiendas bloqueadas (para excluir)
blocked_stores AS (
    SELECT DISTINCT related_id AS store_id
    FROM hive_metastore.moltres.mwp_tags
    WHERE type = 'store'
        AND tag IN ('sre-block-store-429', 'sre-block-store-404')
)

-- Query principal
SELECT
    CASE
        -- Lógica original adaptada para usar la clasificación combinada (type + vertifier)
        WHEN sc.final_classification IN ('clothing_accesories','clothing','jewelry','fashion','apparel','accessories') THEN 'clothing'
        WHEN sc.final_classification IN ('gifts','bookstore_graphic','books','education','art','stationery') THEN 'books'
        WHEN sc.final_classification IN ('electronics_it','electronics','technology','computers','phones') THEN 'electronics_it'
        WHEN sc.final_classification IN ('health_beauty','beauty','cosmetics','health','wellness') THEN 'health_beauty'
        WHEN sc.final_classification IN ('food_drinks','food','drinks','beverages','restaurant') THEN 'food_drinks'
        WHEN sc.final_classification IN ('home_garden','home','garden','furniture','decor') THEN 'home_garden'
        ELSE 'other'
    END AS vertical,
    
    SUM(o.total) AS gmv,
    COUNT(*) AS orders,
    CASE 
        WHEN COUNT(*) > 0 THEN CAST(SUM(o.total) AS DECIMAL(18,2)) / COUNT(*) 
        ELSE 0 
    END AS avg_ticket

FROM hive_metastore.moltres.mwp_store_info i
    INNER JOIN hive_metastore.orders.mwp_orders o 
        ON o.store_id = i.id
    LEFT JOIN store_classification sc 
        ON sc.store_id = i.id
    LEFT JOIN blocked_stores bs 
        ON bs.store_id = i.id

WHERE i.country = 'AR'
    AND i.state <> 4
    AND o.payment_status = 'paid'
    AND o.status <> 'cancelled'
    AND o.completed_at IS NOT NULL
    AND o.storefront <> 'permalink'
    AND o.total_in_usd <= 10000
    -- Conversión de timezone en Databricks (UTC a Buenos Aires)
    AND from_utc_timestamp(o.completed_at, 'America/Argentina/Buenos_Aires') >= timestamp '2024-11-03 20:00:00'
    AND from_utc_timestamp(o.completed_at, 'America/Argentina/Buenos_Aires') < timestamp '2024-11-11 00:00:00'
    -- Excluir tiendas bloqueadas
    AND bs.store_id IS NULL

GROUP BY 1
ORDER BY gmv DESC;
