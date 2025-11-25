/*
Intermediate Model: GMV Rolling Windows Consolidation
Description: Calcula GMV y órdenes en ventanas rolling (30, 60, 90, 360 días desde hoy) por tienda
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Sub-domain: product_marketing

Este modelo intermedio consolida la lógica de cálculo de GMV en ventanas rolling:
- Agrega desde g__operations__orders_gmv_store__agg_daily
- Calcula SUM(gmv) y SUM(gmv_usd) para ventanas de 30, 60, 90, 360 días desde hoy
- Calcula COUNT(DISTINCT orders) para las mismas ventanas
- Filtra órdenes con total_in_usd <= 10000 (ya filtrado en el daily)

El modelo GOLD solo consumirá este intermediate y manejará la incrementalidad.
*/

WITH 
-- Base: todas las tiendas desde store_core
all_stores AS (
    SELECT 
        store_id,
        sys_audit_updated_on
    FROM {{ ref('s__attributes__store_core__ref') }}
),

-- Agregación de GMV por store_id y date desde el daily
daily_gmv AS (
    SELECT
        o.store_id,
        o.date,
        o.gmv,
        o.gmv_usd,
        o.orders
    FROM {{ ref('g__operations__orders_gmv_store__agg_daily') }} o
    INNER JOIN all_stores s ON o.store_id = s.store_id
    WHERE o.date >= DATEADD(DAY, -360, CURRENT_DATE)
        AND o.date <= CURRENT_DATE
        -- Nota: El filtro de total_in_usd <= 10000 ya está aplicado en el daily
),

-- Agregación por store_id con ventanas rolling desde hoy
gmv_rolling AS (
    SELECT
        store_id,
        -- GMV en moneda local (30, 60, 90, 360 días)
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 30 THEN gmv ELSE 0 END) AS gmv30,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 60 THEN gmv ELSE 0 END) AS gmv60,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 90 THEN gmv ELSE 0 END) AS gmv90,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 360 THEN gmv ELSE 0 END) AS gmv360,
        -- GMV en USD (30, 60, 90, 360 días)
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 30 THEN gmv_usd ELSE 0 END) AS gmv_dol_30,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 60 THEN gmv_usd ELSE 0 END) AS gmv_dol_60,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 90 THEN gmv_usd ELSE 0 END) AS gmv_dol_90,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 360 THEN gmv_usd ELSE 0 END) AS gmv_dol_360,
        -- Órdenes (30, 60, 90, 360 días)
        -- Nota: orders en el daily ya es COUNT(DISTINCT order_id) por día, así que SUM es correcto
        -- para obtener el total de órdenes únicas en la ventana
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 30 THEN orders ELSE 0 END) AS orders30,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 60 THEN orders ELSE 0 END) AS orders60,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 90 THEN orders ELSE 0 END) AS orders90,
        SUM(CASE WHEN DATEDIFF(DAY, date, CURRENT_DATE) <= 360 THEN orders ELSE 0 END) AS orders360,
        -- Timestamp para incrementalidad (última fecha procesada)
        MAX(date) AS last_gmv_date
    FROM daily_gmv
    GROUP BY store_id
)

SELECT
    as_base.store_id,
    gr.gmv30,
    gr.gmv60,
    gr.gmv90,
    gr.gmv360,
    gr.gmv_dol_30,
    gr.gmv_dol_60,
    gr.gmv_dol_90,
    gr.gmv_dol_360,
    gr.orders30,
    gr.orders60,
    gr.orders90,
    gr.orders360,
    -- Timestamp para incrementalidad
    -- IMPORTANTE: Incluye CURRENT_DATE para forzar recálculo diario de ventanas rolling
    -- Las ventanas rolling (30, 60, 90, 360 días) dependen de CURRENT_DATE, por lo que
    -- deben recalcularse cada día incluso si no hay nuevas órdenes
    GREATEST(
        as_base.sys_audit_updated_on,
        COALESCE(CAST(gr.last_gmv_date AS TIMESTAMP), TIMESTAMP '1900-01-01'),
        CAST(CURRENT_DATE AS TIMESTAMP)
    ) AS change_timestamp
FROM all_stores as_base
LEFT JOIN gmv_rolling gr ON as_base.store_id = gr.store_id

