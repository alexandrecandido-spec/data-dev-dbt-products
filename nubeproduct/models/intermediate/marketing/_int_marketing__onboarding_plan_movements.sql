{{
    config(
        materialized='ephemeral',
        tags=['marketing']
    )
}}

-- depends_on:
--   - {{ ref('moltres__contracts') }}
--   - {{ ref('s__attributes__store_core__ref') }}
--   - {{ ref('s__general__grouping_plans__ref') }}

/*
Intermediate Model: Plan Movements for Onboarding
Description: Calcula upgrades y downgrades de planes en ventanas de tiempo (7, 15, 30 días)
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Used by: g__product_marketing__onboarding_4_steps_store__agg

Este modelo intermedio calcula:
- Primeiro plano (primer plan contratado)
- Plan máximo alcanzado en cada ventana (7, 15, 30 días)
- Plan al final de cada ventana
- Flags de upgrade/downgrade por ventana
*/

-- ============================================
-- PLAN MOVEMENTS: Upgrade/downgrade de planes
-- Calculado desde moltres__contracts comparando group_order_id de planes
-- ============================================
contracts_with_plan_info AS (
    SELECT 
        c.store_id,
        c.plan_id,
        c.created_at,
        c.start_date,
        gp.grupo AS plan_group,
        CASE 
            WHEN gp.grupo IN ('test_broken','no-stores') THEN 0
            WHEN gp.grupo IN ('zero-fee','freemium') THEN 1
            WHEN gp.grupo IN ('lojinha','plan-a','plan-emprendedor') THEN 2
            WHEN gp.grupo IN ('plan-b') THEN 3
            WHEN gp.grupo IN ('plan-c') THEN 4
            WHEN gp.grupo IN ('enterprise') THEN 5
            ELSE -1 
        END AS plan_order_id,
        s.created_at AS store_created_at
    FROM {{ ref('moltres__contracts') }} c
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON c.store_id = s.store_id
        AND s.created_at >= '2024-01-01'
    LEFT JOIN {{ ref('s__general__grouping_plans__ref') }} gp
        ON c.plan_id = gp.plan
    WHERE c.plan_id IS NOT NULL
),

first_plan AS (
    SELECT 
        store_id,
        plan_group AS primeiro_plano,
        plan_order_id AS first_plan_order_id
    FROM (
        SELECT 
            store_id,
            plan_group,
            plan_order_id,
            ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY created_at ASC, start_date ASC) AS rn
        FROM contracts_with_plan_info
    ) ranked
    WHERE rn = 1
),

max_plan_by_window AS (
    SELECT 
        store_id,
        MAX(CASE WHEN DATEDIFF(DAY, store_created_at, DATE(created_at)) <= 7 THEN plan_order_id ELSE -1 END) AS max_plan_order_d7,
        MAX(CASE WHEN DATEDIFF(DAY, store_created_at, DATE(created_at)) <= 15 THEN plan_order_id ELSE -1 END) AS max_plan_order_d15,
        MAX(CASE WHEN DATEDIFF(DAY, store_created_at, DATE(created_at)) <= 30 THEN plan_order_id ELSE -1 END) AS max_plan_order_d30,
        MAX(CASE WHEN DATEDIFF(DAY, store_created_at, DATE(created_at)) <= 7 THEN plan_group ELSE NULL END) AS max_plan_d7,
        MAX(CASE WHEN DATEDIFF(DAY, store_created_at, DATE(created_at)) <= 15 THEN plan_group ELSE NULL END) AS max_plan_d15,
        MAX(CASE WHEN DATEDIFF(DAY, store_created_at, DATE(created_at)) <= 30 THEN plan_group ELSE NULL END) AS max_plan_d30
    FROM contracts_with_plan_info
    GROUP BY store_id
),

-- Plan al final de cada ventana (último plan activo dentro de la ventana)
-- Usamos ROW_NUMBER para obtener el último contrato dentro de cada ventana
contracts_ranked_by_window AS (
    SELECT 
        c.store_id,
        c.plan_order_id,
        DATEDIFF(DAY, c.store_created_at, DATE(c.created_at)) AS days_from_creation,
        ROW_NUMBER() OVER (
            PARTITION BY c.store_id, 
                CASE 
                    WHEN DATEDIFF(DAY, c.store_created_at, DATE(c.created_at)) <= 7 THEN 7
                    WHEN DATEDIFF(DAY, c.store_created_at, DATE(c.created_at)) <= 15 THEN 15
                    WHEN DATEDIFF(DAY, c.store_created_at, DATE(c.created_at)) <= 30 THEN 30
                    ELSE NULL
                END
            ORDER BY c.created_at DESC, c.start_date DESC
        ) AS rn
    FROM contracts_with_plan_info c
    WHERE DATEDIFF(DAY, c.store_created_at, DATE(c.created_at)) <= 30
),

plan_at_end_of_window AS (
    SELECT 
        store_id,
        MAX(CASE WHEN days_from_creation <= 7 AND rn = 1 THEN plan_order_id ELSE -1 END) AS plan_order_d7,
        MAX(CASE WHEN days_from_creation <= 15 AND rn = 1 THEN plan_order_id ELSE -1 END) AS plan_order_d15,
        MAX(CASE WHEN days_from_creation <= 30 AND rn = 1 THEN plan_order_id ELSE -1 END) AS plan_order_d30
    FROM contracts_ranked_by_window
    GROUP BY store_id
)

SELECT 
    sc.store_id,
    fp.primeiro_plano,
    mp.max_plan_d7,
    mp.max_plan_d15,
    mp.max_plan_d30,
    -- Upgrade: si el plan máximo en la ventana es mayor que el primer plan
    CASE WHEN mp.max_plan_order_d7 > COALESCE(fp.first_plan_order_id, -1) THEN 1 ELSE 0 END AS upgrade_d7,
    CASE WHEN mp.max_plan_order_d15 > COALESCE(fp.first_plan_order_id, -1) THEN 1 ELSE 0 END AS upgrade_d15,
    CASE WHEN mp.max_plan_order_d30 > COALESCE(fp.first_plan_order_id, -1) THEN 1 ELSE 0 END AS upgrade_d30,
    -- Downgrade: si el plan al final de la ventana es menor que el plan máximo alcanzado en esa ventana
    CASE 
        WHEN mp.max_plan_order_d7 > 0 
            AND pe.plan_order_d7 >= 0 
            AND pe.plan_order_d7 < mp.max_plan_order_d7 
        THEN 1 
        ELSE 0 
    END AS downgrade_d7,
    CASE 
        WHEN mp.max_plan_order_d15 > 0 
            AND pe.plan_order_d15 >= 0 
            AND pe.plan_order_d15 < mp.max_plan_order_d15 
        THEN 1 
        ELSE 0 
    END AS downgrade_d15,
    CASE 
        WHEN mp.max_plan_order_d30 > 0 
            AND pe.plan_order_d30 >= 0 
            AND pe.plan_order_d30 < mp.max_plan_order_d30 
        THEN 1 
        ELSE 0 
    END AS downgrade_d30
FROM {{ ref('s__attributes__store_core__ref') }} sc
LEFT JOIN first_plan fp ON sc.store_id = fp.store_id
LEFT JOIN max_plan_by_window mp ON sc.store_id = mp.store_id
LEFT JOIN plan_at_end_of_window pe ON sc.store_id = pe.store_id
WHERE sc.created_at >= '2024-01-01'

