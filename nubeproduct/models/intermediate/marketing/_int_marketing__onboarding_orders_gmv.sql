{{
    config(
        materialized='ephemeral',
        tags=['marketing']
    )
}}

-- depends_on:
--   - {{ ref('s__attributes__store_core__ref') }}
--   - {{ ref('company_metrics_paid_orders') }}

/*
Intermediate Model: Orders & GMV Metrics for Onboarding
Description: Calcula métricas de órdenes y GMV en ventanas de tiempo desde creación de tienda
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Used by: g__product_marketing__onboarding_4_steps_store__agg

Este modelo intermedio calcula:
- Primera orden completada y tiempo hasta primera orden
- Conteo de órdenes por ventana (7, 15, 30, 60, 90 días)
- GMV en moneda local y USD por ventana (30, 60, 90 días)
*/

-- ============================================
-- ORDERS & GMV: Métricas de órdenes y GMV
-- Calculado desde company_metrics_paid_orders
-- ============================================
store_created_dates AS (
    SELECT DISTINCT
        store_id,
        created_at AS store_created_at
    FROM {{ ref('s__attributes__store_core__ref') }}
    WHERE created_at >= '2024-01-01'
),

orders_gmv_base AS (
    SELECT 
        o.store_id,
        scd.store_created_at,
        o.id AS order_id,
        DATE(o.completed_at) AS completed_date,
        o.total,
        o.total_in_usd,
        DATEDIFF(DAY, scd.store_created_at, DATE(o.completed_at)) AS days_since_store_creation
    FROM {{ ref('company_metrics_paid_orders') }} o
    INNER JOIN store_created_dates scd
        ON o.store_id = scd.store_id
    WHERE o.completed_at IS NOT NULL
        AND o.total_in_usd >= 0
        AND o.total_in_usd < 10000  -- Filtrar outliers según especificación
)

SELECT 
    store_id,
    -- Primera orden completada
    MIN(completed_date) AS first_order,
    -- Días desde creación de tienda hasta primera orden
    MIN(days_since_store_creation) AS time_to_first_order,
    -- Conteo de órdenes por ventana de tiempo desde creación de tienda
    COUNT(DISTINCT CASE WHEN days_since_store_creation <= 7 THEN order_id ELSE NULL END) AS orders_7,
    COUNT(DISTINCT CASE WHEN days_since_store_creation <= 15 THEN order_id ELSE NULL END) AS orders_15,
    COUNT(DISTINCT CASE WHEN days_since_store_creation <= 30 THEN order_id ELSE NULL END) AS orders_30,
    COUNT(DISTINCT CASE WHEN days_since_store_creation <= 60 THEN order_id ELSE NULL END) AS orders_60,
    COUNT(DISTINCT CASE WHEN days_since_store_creation <= 90 THEN order_id ELSE NULL END) AS orders_90,
    -- GMV en moneda local por ventana de tiempo desde creación de tienda
    SUM(CASE WHEN days_since_store_creation <= 30 THEN COALESCE(total, 0) ELSE 0 END) AS gmv_30,
    SUM(CASE WHEN days_since_store_creation <= 60 THEN COALESCE(total, 0) ELSE 0 END) AS gmv_60,
    SUM(CASE WHEN days_since_store_creation <= 90 THEN COALESCE(total, 0) ELSE 0 END) AS gmv_90,
    -- GMV en USD por ventana de tiempo desde creación de tienda
    SUM(CASE WHEN days_since_store_creation <= 30 THEN COALESCE(total_in_usd, 0) ELSE 0 END) AS gmv_dol_30,
    SUM(CASE WHEN days_since_store_creation <= 60 THEN COALESCE(total_in_usd, 0) ELSE 0 END) AS gmv_dol_60,
    SUM(CASE WHEN days_since_store_creation <= 90 THEN COALESCE(total_in_usd, 0) ELSE 0 END) AS gmv_dol_90
FROM orders_gmv_base
GROUP BY store_id

