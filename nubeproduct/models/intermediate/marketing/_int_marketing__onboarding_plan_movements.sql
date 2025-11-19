-- depends_on:
--   - {{ ref('s__contracts__store_contracts__scd') }}
--   - {{ ref('s__attributes__store_core__ref') }}

/*
Intermediate Model: Plan Movements for Onboarding
Description: Calcula upgrade/downgrade de planes y movimientos de planes en ventanas de tiempo
Owner: jhu.boggio@tiendanube.com
Domain: marketing
Used by: g__product_marketing__onboarding_4_steps_store__agg

Este modelo intermedio calcula:
- Primer plan de la tienda
- Plan máximo alcanzado en ventanas (7, 15, 30 días)
- Plan al final de cada ventana
- Flags de upgrade/downgrade por ventana
*/

-- ============================================
-- PLAN MOVEMENTS: Upgrade/downgrade de planes
-- Calculado desde s__contracts__store_contracts__scd (SILVER) comparando group_order_id de planes
-- ============================================
WITH contracts_with_plan_info AS (
    SELECT 
        c.store_id,
        c.plan_name,
        c.created_at_contract AS created_at,
        c.start_date,
        c.plan_name AS plan_group,
        -- Optimización: Calcular DATEDIFF una vez para evitar recálculos en CTEs siguientes
        DATEDIFF(DAY, s.created_at, DATE(c.created_at_contract)) AS days_from_creation,
        CASE 
            WHEN c.plan_name IN ('test_broken','no-stores') THEN 0
            WHEN c.plan_name IN ('zero-fee','freemium') THEN 1
            WHEN c.plan_name IN ('lojinha','plan-a','plan-emprendedor') THEN 2
            WHEN c.plan_name IN ('plan-b') THEN 3
            WHEN c.plan_name IN ('plan-c') THEN 4
            WHEN c.plan_name IN ('enterprise') THEN 5
            ELSE -1 
        END AS plan_order_id,
        s.created_at AS store_created_at
    FROM {{ ref('s__contracts__store_contracts__scd') }} c
    INNER JOIN {{ ref('s__attributes__store_core__ref') }} s
        ON c.store_id = s.store_id
        AND s.created_at >= '{{ var("onboarding_start_date") }}'
    WHERE c.plan_name IS NOT NULL
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
        -- Optimización: Usar days_from_creation calculado una vez en lugar de recalcular DATEDIFF
        MAX(CASE WHEN days_from_creation <= 7 THEN plan_order_id ELSE -1 END) AS max_plan_order_d7,
        MAX(CASE WHEN days_from_creation <= 15 THEN plan_order_id ELSE -1 END) AS max_plan_order_d15,
        MAX(CASE WHEN days_from_creation <= 30 THEN plan_order_id ELSE -1 END) AS max_plan_order_d30,
        MAX(CASE WHEN days_from_creation <= 7 THEN plan_group ELSE NULL END) AS max_plan_d7,
        MAX(CASE WHEN days_from_creation <= 15 THEN plan_group ELSE NULL END) AS max_plan_d15,
        MAX(CASE WHEN days_from_creation <= 30 THEN plan_group ELSE NULL END) AS max_plan_d30
    FROM contracts_with_plan_info
    GROUP BY store_id
),

-- Plan al final de cada ventana (último plan activo dentro de la ventana)
-- Usamos ROW_NUMBER para obtener el último contrato dentro de cada ventana
contracts_ranked_by_window AS (
    SELECT 
        c.store_id,
        c.plan_order_id,
        c.days_from_creation,
        ROW_NUMBER() OVER (
            PARTITION BY c.store_id, 
                CASE 
                    WHEN c.days_from_creation <= 7 THEN 7
                    WHEN c.days_from_creation <= 15 THEN 15
                    WHEN c.days_from_creation <= 30 THEN 30
                    ELSE NULL
                END
            ORDER BY c.created_at DESC, c.start_date DESC
        ) AS rn
    FROM contracts_with_plan_info c
    WHERE c.days_from_creation <= 30
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
WHERE sc.created_at >= '{{ var("onboarding_start_date") }}'

