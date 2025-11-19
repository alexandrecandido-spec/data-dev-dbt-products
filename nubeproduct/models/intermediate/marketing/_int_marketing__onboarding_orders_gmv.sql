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
-- Optimización: Filtro aplicado directamente en el JOIN para mejor rendimiento
-- Eliminado WITH anidado para evitar problemas de compilación con modelos ephemeral
-- ============================================
SELECT 
    o.store_id,
    -- Primera orden completada
    MIN(DATE(o.completed_at)) AS first_order,
    -- Días desde creación de tienda hasta primera orden
    MIN(DATEDIFF(DAY, sc.created_at, DATE(o.completed_at))) AS time_to_first_order,
    -- Conteo de órdenes por ventana de tiempo desde creación de tienda
    COUNT(DISTINCT CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 7 THEN o.id ELSE NULL END) AS orders_7,
    COUNT(DISTINCT CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 15 THEN o.id ELSE NULL END) AS orders_15,
    COUNT(DISTINCT CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 30 THEN o.id ELSE NULL END) AS orders_30,
    COUNT(DISTINCT CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 60 THEN o.id ELSE NULL END) AS orders_60,
    COUNT(DISTINCT CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 90 THEN o.id ELSE NULL END) AS orders_90,
    -- GMV en moneda local por ventana de tiempo desde creación de tienda
    SUM(CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 30 THEN COALESCE(o.total, 0) ELSE 0 END) AS gmv_30,
    SUM(CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 60 THEN COALESCE(o.total, 0) ELSE 0 END) AS gmv_60,
    SUM(CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 90 THEN COALESCE(o.total, 0) ELSE 0 END) AS gmv_90,
    -- GMV en USD por ventana de tiempo desde creación de tienda
    SUM(CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 30 THEN COALESCE(o.total_in_usd, 0) ELSE 0 END) AS gmv_dol_30,
    SUM(CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 60 THEN COALESCE(o.total_in_usd, 0) ELSE 0 END) AS gmv_dol_60,
    SUM(CASE WHEN DATEDIFF(DAY, sc.created_at, DATE(o.completed_at)) <= 90 THEN COALESCE(o.total_in_usd, 0) ELSE 0 END) AS gmv_dol_90
FROM {{ ref('company_metrics_paid_orders') }} o
INNER JOIN {{ ref('s__attributes__store_core__ref') }} sc
    ON o.store_id = sc.store_id
    AND sc.created_at >= '{{ var("onboarding_start_date") }}'  -- Optimización: Filtro aplicado en el JOIN
WHERE o.completed_at IS NOT NULL
    AND o.total_in_usd >= 0
    AND o.total_in_usd < 10000  -- Filtrar outliers según especificación
GROUP BY o.store_id

