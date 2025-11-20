/*
Intermediate Model: Main Payment Method by GMV Consolidation
Description: Calcula el método de pago principal por GMV para cada tienda (agregación por store)
Owner: jhu.boggio@tiendanube.com
Domain: merchant

Este modelo intermedio consolida la lógica de cálculo del método de pago principal:
- Agrupa órdenes por store_id y payment desde 2024-01-01
- Calcula SUM(total) como GMV por método de pago
- Ranks por GMV DESC para identificar el método principal
- Solo incluye tiendas que tienen órdenes (no hace join con store_core)

El modelo GOLD solo consumirá este intermediate y manejará la incrementalidad.
*/

WITH 
-- Agregación de GMV por store_id y payment desde 2024-01-01
-- Solo incluye tiendas que tienen órdenes pagadas
payment_gmv AS (
    SELECT
        o.store_id,
        o.payment AS gateway_method,
        SUM(o.total) AS gmv,
        COUNT(DISTINCT o.id) AS orders,
        MAX(o.completed_at) AS last_order_date
    FROM {{ ref('company_metrics_paid_orders') }} o
    WHERE o.completed_at >= '2024-01-01'
        AND o.completed_at IS NOT NULL
        AND o.total > 0
    GROUP BY o.store_id, o.payment
),

-- Ranking por GMV DESC para identificar el método principal
ranked_payments AS (
    SELECT
        store_id,
        gateway_method,
        gmv,
        orders,
        last_order_date,
        ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY gmv DESC, orders DESC) AS rank_gmv
    FROM payment_gmv
),

-- Método principal (rank = 1)
main_payment_method AS (
    SELECT
        store_id,
        gateway_method AS main_payment_method,
        gmv AS main_payment_method_gmv,
        orders AS main_payment_method_orders,
        last_order_date AS main_payment_method_last_order_date,
        -- Timestamp para incrementalidad
        GREATEST(
            CAST(last_order_date AS TIMESTAMP),
            CAST('1900-01-01' AS TIMESTAMP)
        ) AS change_timestamp
    FROM ranked_payments
    WHERE rank_gmv = 1
)

SELECT
    mpm.store_id,
    mpm.main_payment_method,
    mpm.main_payment_method_gmv,
    mpm.main_payment_method_orders,
    mpm.main_payment_method_last_order_date,
    mpm.change_timestamp
FROM main_payment_method mpm
