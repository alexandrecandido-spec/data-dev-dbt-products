
WITH tags_info AS (
  SELECT
    t.related_id AS store_id,
    MIN_BY(t.tag, CASE 
      WHEN t.tag = 'billing-churn-vencimientos-extensos' THEN 1
      WHEN t.tag IN ('beneficio-tiendagratuita', 'benefcio-tiendagratuita') THEN 2
      WHEN t.tag IN ('ONG', 'ONG ', 'TAG ONG') THEN 3
      ELSE 4
    END) AS tag,
    MAX(t.sys_audit_updated_on) AS updated_at
  FROM {{ source('int_moltres', 'mwp_tags') }} t
  WHERE t.tag IN ('billing-churn-vencimientos-extensos', 'beneficio-tiendagratuita', 'ONG')
  GROUP BY t.related_id
),

base AS (
    SELECT
        c.id,
        c.store_id,
        c.plan_id,
        p.grupo AS plan_name,
        c.type,
        c.total,
        t.tag,
        CAST(c.created_at AS DATE) AS created_at_contract,
        CAST(start_date AS DATE) AS start_date,
        CAST(end_date AS DATE) AS end_date,
        c.sys_audit_updated_on
    FROM {{ ref('billing__contracts__store_contract__scd') }} c
    LEFT JOIN {{ ref('s__general__grouping_plans__ref') }} p on p.plan = c.plan_id
    LEFT JOIN tags_info t on t.store_id = c.store_id
    INNER JOIN {{ ref('s__lifecycle__store_status__ref') }} ss on c.store_id = ss.store_id
),

-- 1️⃣ Ordenamos para detectar cambios
ordered AS (
    SELECT
        id,
        store_id,
        plan_id,
        plan_name,
        type,
        total,
        tag,
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
    END AS new_block_flag,
    CASE
        WHEN start_date < '2000-01-01' THEN 'data_anomaly' -- fechas anomalas
        WHEN prev_end_date IS NULL THEN 'first_contract' -- primer contrato
        WHEN plan_name != prev_plan THEN 'plan_changed' -- cambio de plan
        WHEN start_date > prev_end_date THEN 'gap_between_periods' -- gap entre periodos
        WHEN type != prev_type THEN 'type_changed' -- cambio de tipo
        ELSE 'unclassified' -- no clasificado
    END AS change_reason_trigger
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
            IGNORE NULLS OVER (PARTITION BY store_id, group_id ORDER BY start_date, id) AS main_type,
        FIRST_VALUE(change_reason_trigger) IGNORE NULLS
            OVER (PARTITION BY store_id, group_id ORDER BY start_date, id) AS change_reason,
        FIRST_VALUE(plan_id) OVER (PARTITION BY store_id, group_id ORDER BY created_at_contract ASC) AS main_plan_id
    FROM grouped g
),

-- 5️⃣ Consolidamos por bloque
block_agg AS (
SELECT
    store_id,
    main_plan_id AS plan_id,
    plan_name,
    main_type AS contract_type,
    tag,
    SUM(total) AS contracts_total,
    MIN(id)                   AS contract_id,
    MIN(created_at_contract)  AS created_at_contract,
    MIN(start_date)           AS start_date,
    MAX(end_date)             AS end_date,
    MAX(sys_audit_updated_on) AS sys_audit_updated_on,
    MAX(change_reason)        AS change_reason
FROM typed
GROUP BY store_id, main_plan_id, plan_name, main_type, tag, group_id
),

-- 6️⃣ Marcamos el contrato actual por store
final AS (
SELECT
    *,
    ROW_NUMBER() OVER (
             PARTITION BY store_id
             ORDER BY
                created_at_contract DESC,   -- 🥇 contrato creado más recientemente
                start_date DESC,            -- 🥈 si hay empate, el que empezó más recientemente
                end_date DESC               -- 🥉 si aún hay empate, el que termina más tarde
           ) as rn_current
FROM block_agg
),

--7️⃣ arreglamos el plan_name para los data_anomaly con tag de billing-churn-vencimientos-extensos y contact_type = 'pre-churn-lead'
data_anomaly_fix AS (
    SELECT
        a.*,
        CASE WHEN a.change_reason = 'data_anomaly' AND a.contract_type = 'pre-churn-lead' AND a.rn_current = 1 THEN 'freemium' ELSE a.plan_name END AS main_plan_name,
        CASE 
            WHEN a.change_reason = 'data_anomaly' AND a.tag = 'billing-churn-vencimientos-extensos' THEN created_at_contract 
            WHEN a.change_reason = 'data_anomaly' AND (a.tag = 'ONG' OR a.tag IS NULL) AND a.contract_type in ('pre-churn-lead', 'pre-churn', 'standard', 'free-days', 'url-free-days','freemium') THEN created_at_contract
            ELSE start_date END AS main_start_date,
        CASE 
            WHEN a.change_reason = 'data_anomaly' AND a.tag = 'billing-churn-vencimientos-extensos' AND a.contract_type in ('pre-churn-lead', 'pre-churn') THEN created_at_contract 
            WHEN a.change_reason = 'data_anomaly' AND a.tag = 'billing-churn-vencimientos-extensos' AND a.contract_type in ('free-days','standard','recurring-edge-case') THEN LEAD(created_at_contract) OVER (PARTITION BY store_id ORDER BY created_at_contract, start_date) 
            WHEN a.change_reason = 'data_anomaly' AND (a.tag = 'ONG' OR a.tag IS NULL) AND a.contract_type in ('pre-churn-lead', 'pre-churn') THEN created_at_contract 
            WHEN a.change_reason = 'data_anomaly' AND (a.tag = 'ONG' OR a.tag IS NULL) AND a.contract_type in ('standard','free-days','url-free-days','freemium') THEN LEAD(created_at_contract) OVER (PARTITION BY store_id ORDER BY created_at_contract, start_date) 
            ELSE end_date END AS main_end_date
    FROM final a
)

SELECT
  store_id,
  plan_id,
  main_plan_name AS plan_name,
  contract_type,
  contracts_total,
  contract_id,
  created_at_contract,
  main_start_date AS start_date_contract,
  main_end_date AS end_date_contract,
  sys_audit_updated_on,
  change_reason,
  CASE WHEN rn_current = 1 THEN TRUE ELSE FALSE END AS is_current,
  ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY created_at_contract, start_date) AS contract_order,
  COUNT(*) OVER (PARTITION BY store_id) AS contracts_qty,
  tag,
  CASE WHEN MAX(CASE WHEN change_reason = 'data_anomaly' THEN 1 ELSE 0 END) OVER (PARTITION BY store_id) = 1 THEN TRUE ELSE FALSE END AS merchant_has_anomaly
FROM data_anomaly_fix
ORDER BY store_id, contract_id, start_date ASC