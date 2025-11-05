WITH base AS (
    SELECT
        c.id,
        c.store_id,
        c.plan_id,
        p.grupo AS plan_name,
        c.type,
        CAST(c.created_at AS DATE) AS created_at_contract,
        CAST(start_date AS DATE) AS start_date,
        CAST(end_date AS DATE) AS end_date,
        c.sys_audit_updated_on
    FROM {{ ref('billing__contracts__store_contract__scd') }} c
    left join {{ ref('s__general__grouping_plans__ref') }} p on p.plan = c.plan_id
),

-- 1️⃣ Ordenamos para detectar cambios
ordered AS (
    SELECT
        id,
        store_id,
        plan_name,
        type,
        created_at_contract,
        start_date,
        end_date,
        sys_audit_updated_on,
        LAG(end_date) OVER (PARTITION BY store_id ORDER BY id) AS prev_end_date,
        LAG(plan_name) OVER (PARTITION BY store_id ORDER BY id) AS prev_plan,
        LAG(type) OVER (PARTITION BY store_id ORDER BY start_date, end_date) AS prev_type
    FROM base
),

-- 2️⃣ Detectamos inicio de nuevo bloque
flags AS (
  SELECT
    *,
    CASE
        WHEN prev_end_date IS NULL THEN 1
        -- 🔹 cambia de plan
        WHEN plan_name != prev_plan THEN 1
        -- 🔹 si cambia el plan, SIEMPRE nuevo bloque
        WHEN start_date > prev_end_date THEN 1
        -- 🔹 hay gap entre periodos (no continuidad)
        WHEN type IN ('change-plan','change-plan-free-until-next-bill')
           AND COALESCE(plan_name,'~') = COALESCE(prev_plan,'~') THEN 0
        -- 🔹 si es change-plan* y NO cambió el plan, NO abrir bloque
        WHEN type != prev_type THEN 1
        -- 🔹 cambia de tipo (por ejemplo trial → standard o pre-churn → standard)
        ELSE 0
    END AS new_block_flag
  FROM ordered
),

-- 3️⃣ Creamos identificador de bloque acumulativo
grouped AS (
    SELECT
        *,
        SUM(new_block_flag) OVER (
            PARTITION BY store_id ORDER BY start_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS group_id
    FROM flags
),

-- 4️⃣ Determinamos el tipo representativo del bloque
typed AS (
    SELECT
        g.*,
        FIRST_VALUE(CASE 
            WHEN type NOT IN ('change-plan','change-plan-free-until-next-bill') 
            THEN type END) 
            IGNORE NULLS OVER (PARTITION BY store_id, group_id ORDER BY start_date, id) AS main_type
    FROM grouped g
)

-- 5️⃣ Consolidamos por bloque
SELECT
store_id,
plan_name,
main_type AS contract_type,
MIN(id) AS contract_id,
MIN(created_at_contract) AS created_at_contract,
MIN(start_date) AS start_date,
MAX(end_date) AS end_date,
MAX(sys_audit_updated_on) AS sys_audit_updated_on
FROM typed
GROUP BY store_id, plan_name, main_type, group_id
ORDER BY store_id, start_date