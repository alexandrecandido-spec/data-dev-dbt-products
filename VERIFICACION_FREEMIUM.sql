-- ============================================================================
-- VERIFICACIÓN: Comportamiento de Payments y Shipping en Tiendas Freemium
-- ============================================================================
-- Objetivo: Verificar si las tiendas freemium tienen automáticamente
--           eventos de payments y carriers de shipping registrados
-- ============================================================================

-- ============================================================================
-- CONSULTA 1: Verificar Payments en Tiendas Freemium
-- ============================================================================
-- Pregunta: ¿Las tiendas freemium tienen eventos PaymentProviderRegistered
--           registrados automáticamente al crearse?
-- ============================================================================

WITH freemium_stores AS (
    SELECT 
        s.store_id,
        s.created_at AS store_created_at,
        pg.grupo AS plan_group,
        pg.namev2 AS plan_name,
        s.country_code AS country
    FROM `data_products_dev`.`testing_merchant`.`s__attributes__store_core__ref` s
    INNER JOIN `hive_metastore`.`moltres`.`mwp_store_info` si
        ON s.store_id = si.id
    LEFT JOIN `data_products_dev`.`testing_operations`.`operations_grouping_plans` pg 
        ON si.plan = pg.plan
    WHERE pg.grupo = 'freemium'
        AND s.created_at >= '2024-01-01'
        AND s.created_at <= CURRENT_DATE()
),

payment_events AS (
    SELECT
        CAST(jpps.storeId AS BIGINT) AS store_id,
        MIN(jpps.utcDateTime) AS first_payment_event,
        MAX(jpps.utcDateTime) AS last_payment_event,
        COUNT(*) AS total_payment_events
    FROM `hive_metastore`.`payments`.`journal_payment_provider` jpps
    WHERE ARRAY_CONTAINS(jpps.event_tg, 'PaymentProviderRegistered')
    GROUP BY CAST(jpps.storeId AS BIGINT)
)

SELECT 
    fs.store_id,
    fs.store_created_at,
    fs.plan_group,
    fs.plan_name,
    fs.country,
    CASE 
        WHEN pe.store_id IS NOT NULL THEN 1 
        ELSE 0 
    END AS has_payment_event,
    pe.first_payment_event,
    pe.last_payment_event,
    pe.total_payment_events,
    -- Diferencia en días entre creación de tienda y primer evento de pago
    CASE 
        WHEN pe.first_payment_event IS NOT NULL 
        THEN DATEDIFF(DATE(pe.first_payment_event), DATE(fs.store_created_at))
        ELSE NULL
    END AS days_between_store_creation_and_first_payment_event
FROM freemium_stores fs
LEFT JOIN payment_events pe ON fs.store_id = pe.store_id
ORDER BY fs.store_created_at DESC
LIMIT 100;


-- ============================================================================
-- CONSULTA 2: Resumen de Payments en Freemium
-- ============================================================================
-- Muestra estadísticas agregadas sobre cuántas tiendas freemium tienen
-- eventos de payments registrados
-- ============================================================================

WITH freemium_stores AS (
    SELECT 
        s.store_id,
        s.created_at AS store_created_at,
        pg.grupo AS plan_group
    FROM `data_products_dev`.`testing_merchant`.`s__attributes__store_core__ref` s
    INNER JOIN `hive_metastore`.`moltres`.`mwp_store_info` si
        ON s.store_id = si.id
    LEFT JOIN `data_products_dev`.`testing_operations`.`operations_grouping_plans` pg 
        ON si.plan = pg.plan
    WHERE pg.grupo = 'freemium'
        AND s.created_at >= '2024-01-01'
        AND s.created_at <= CURRENT_DATE()
),

payment_events AS (
    SELECT DISTINCT
        CAST(jpps.storeId AS BIGINT) AS store_id
    FROM `hive_metastore`.`payments`.`journal_payment_provider` jpps
    WHERE ARRAY_CONTAINS(jpps.event_tg, 'PaymentProviderRegistered')
)

SELECT 
    COUNT(DISTINCT fs.store_id) AS total_freemium_stores,
    COUNT(DISTINCT pe.store_id) AS freemium_stores_with_payment_events,
    COUNT(DISTINCT fs.store_id) - COUNT(DISTINCT pe.store_id) AS freemium_stores_without_payment_events,
    ROUND(
        COUNT(DISTINCT pe.store_id) * 100.0 / COUNT(DISTINCT fs.store_id), 
        2
    ) AS percentage_with_payment_events
FROM freemium_stores fs
LEFT JOIN payment_events pe ON fs.store_id = pe.store_id;


-- ============================================================================
-- CONSULTA 3: Verificar Shipping en Tiendas Freemium
-- ============================================================================
-- Pregunta: ¿Las tiendas freemium tienen carriers activos creados
--           automáticamente al crearse?
-- ============================================================================

WITH freemium_stores AS (
    SELECT 
        s.store_id,
        s.created_at AS store_created_at,
        pg.grupo AS plan_group,
        pg.namev2 AS plan_name,
        s.country_code AS country
    FROM `data_products_dev`.`testing_merchant`.`s__attributes__store_core__ref` s
    INNER JOIN `hive_metastore`.`moltres`.`mwp_store_info` si
        ON s.store_id = si.id
    LEFT JOIN `data_products_dev`.`testing_operations`.`operations_grouping_plans` pg 
        ON si.plan = pg.plan
    WHERE pg.grupo = 'freemium'
        AND s.created_at >= '2024-01-01'
        AND s.created_at <= CURRENT_DATE()
),

shipping_carriers AS (
    SELECT
        sc.store_id,
        MIN(sc.created_at) AS first_carrier_date,
        MAX(sc.created_at) AS last_carrier_date,
        COUNT(DISTINCT sc.id) AS total_active_carriers
    FROM `hive_metastore`.`moltres`.`mwp_shipping_carriers` sc
    INNER JOIN `hive_metastore`.`moltres`.`mwp_shipping_carriers_options` sco
        ON sc.id = sco.carrier_id
    WHERE sc.status = 1  -- 1 = active carrier
        AND sco.status = 1  -- 1 = active option
        AND sc.deleted_at IS NULL
        AND sco.deleted_at IS NULL
    GROUP BY sc.store_id
)

SELECT 
    fs.store_id,
    fs.store_created_at,
    fs.plan_group,
    fs.plan_name,
    fs.country,
    CASE 
        WHEN sc.store_id IS NOT NULL THEN 1 
        ELSE 0 
    END AS has_active_carrier,
    sc.first_carrier_date,
    sc.last_carrier_date,
    sc.total_active_carriers,
    -- Diferencia en días entre creación de tienda y primer carrier
    CASE 
        WHEN sc.first_carrier_date IS NOT NULL 
        THEN DATEDIFF(DATE(sc.first_carrier_date), DATE(fs.store_created_at))
        ELSE NULL
    END AS days_between_store_creation_and_first_carrier
FROM freemium_stores fs
LEFT JOIN shipping_carriers sc ON fs.store_id = sc.store_id
ORDER BY fs.store_created_at DESC
LIMIT 100;


-- ============================================================================
-- CONSULTA 4: Resumen de Shipping en Freemium
-- ============================================================================
-- Muestra estadísticas agregadas sobre cuántas tiendas freemium tienen
-- carriers activos registrados
-- ============================================================================

WITH freemium_stores AS (
    SELECT 
        s.store_id,
        s.created_at AS store_created_at,
        pg.grupo AS plan_group
    FROM `data_products_dev`.`testing_merchant`.`s__attributes__store_core__ref` s
    INNER JOIN `hive_metastore`.`moltres`.`mwp_store_info` si
        ON s.store_id = si.id
    LEFT JOIN `data_products_dev`.`testing_operations`.`operations_grouping_plans` pg 
        ON si.plan = pg.plan
    WHERE pg.grupo = 'freemium'
        AND s.created_at >= '2024-01-01'
        AND s.created_at <= CURRENT_DATE()
),

shipping_carriers AS (
    SELECT DISTINCT
        sc.store_id
    FROM `hive_metastore`.`moltres`.`mwp_shipping_carriers` sc
    INNER JOIN `hive_metastore`.`moltres`.`mwp_shipping_carriers_options` sco
        ON sc.id = sco.carrier_id
    WHERE sc.status = 1  -- 1 = active carrier
        AND sco.status = 1  -- 1 = active option
        AND sc.deleted_at IS NULL
        AND sco.deleted_at IS NULL
)

SELECT 
    COUNT(DISTINCT fs.store_id) AS total_freemium_stores,
    COUNT(DISTINCT sc.store_id) AS freemium_stores_with_active_carriers,
    COUNT(DISTINCT fs.store_id) - COUNT(DISTINCT sc.store_id) AS freemium_stores_without_active_carriers,
    ROUND(
        COUNT(DISTINCT sc.store_id) * 100.0 / COUNT(DISTINCT fs.store_id), 
        2
    ) AS percentage_with_active_carriers
FROM freemium_stores fs
LEFT JOIN shipping_carriers sc ON fs.store_id = sc.store_id;


-- ============================================================================
-- CONSULTA 5: Comparación entre Freemium y Trial (para contexto)
-- ============================================================================
-- Compara el comportamiento de payments y shipping entre freemium y trial
-- para entender si hay diferencias
-- ============================================================================

WITH stores_by_plan AS (
    SELECT 
        s.store_id,
        s.created_at AS store_created_at,
        pg.grupo AS plan_group
    FROM `data_products_dev`.`testing_merchant`.`s__attributes__store_core__ref` s
    INNER JOIN `hive_metastore`.`moltres`.`mwp_store_info` si
        ON s.store_id = si.id
    LEFT JOIN `data_products_dev`.`testing_operations`.`operations_grouping_plans` pg 
        ON si.plan = pg.plan
    WHERE pg.grupo IN ('freemium', 'plan-a')  -- plan-a como ejemplo de trial/paid
        AND s.created_at >= '2024-01-01'
        AND s.created_at <= CURRENT_DATE()
),

payment_events AS (
    SELECT DISTINCT
        CAST(jpps.storeId AS BIGINT) AS store_id
    FROM `hive_metastore`.`payments`.`journal_payment_provider` jpps
    WHERE ARRAY_CONTAINS(jpps.event_tg, 'PaymentProviderRegistered')
),

shipping_carriers AS (
    SELECT DISTINCT
        sc.store_id
    FROM `hive_metastore`.`moltres`.`mwp_shipping_carriers` sc
    INNER JOIN `hive_metastore`.`moltres`.`mwp_shipping_carriers_options` sco
        ON sc.id = sco.carrier_id
    WHERE sc.status = 1
        AND sco.status = 1
        AND sc.deleted_at IS NULL
        AND sco.deleted_at IS NULL
)

SELECT 
    sbp.plan_group,
    COUNT(DISTINCT sbp.store_id) AS total_stores,
    COUNT(DISTINCT pe.store_id) AS stores_with_payment_events,
    COUNT(DISTINCT sc.store_id) AS stores_with_active_carriers,
    ROUND(
        COUNT(DISTINCT pe.store_id) * 100.0 / COUNT(DISTINCT sbp.store_id), 
        2
    ) AS pct_with_payment_events,
    ROUND(
        COUNT(DISTINCT sc.store_id) * 100.0 / COUNT(DISTINCT sbp.store_id), 
        2
    ) AS pct_with_active_carriers
FROM stores_by_plan sbp
LEFT JOIN payment_events pe ON sbp.store_id = pe.store_id
LEFT JOIN shipping_carriers sc ON sbp.store_id = sc.store_id
GROUP BY sbp.plan_group
ORDER BY sbp.plan_group;

