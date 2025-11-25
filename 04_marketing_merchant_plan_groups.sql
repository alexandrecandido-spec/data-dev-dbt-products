-- ==============================================
-- QUERY 4/5: PLAN GROUPS CLASSIFICATION
-- ==============================================
-- Esta query obtiene group_name usando la lógica de operations_grouping_plans
-- Join key: store_id

WITH 
-- Base de tiendas con plan info
base_stores AS (
  SELECT 
    id AS store_id,
    plan AS plan_id_nk,
    country AS country_code
  FROM hive_metastore.moltres.mwp_store_info
  WHERE state != 4 AND country IN ('AR')
),

-- Plans countries info
plans_countries AS (
  SELECT 
    id AS plan_countries_id,
    plan AS plan_id,
    country AS country_code
  FROM hive_metastore.moltres.mwp_plans_countries
),

-- Plans info
plans_info AS (
  SELECT 
    id AS plan_id,
    nice_name
  FROM hive_metastore.moltres.mwp_plans
),

-- Manual plan group mapping usando la tabla real de data_manual
manual_plan_groups AS (
  SELECT 
    plan AS plan_countries_id,  -- En el seed, 'plan' corresponde a plan_countries.id
    grupo,
    namev2
  FROM hive_metastore.data_manual.operations__grouping_plans_aux
),

-- Plan group classification usando datos reales + fallback logic
plan_group_classification AS (
  SELECT
    pc.plan_countries_id,
    pc.country_code,
    pi.nice_name,
    
    -- Grupo: priorizar data_manual, fallback a lógica por nice_name
    CASE
      WHEN mpg.grupo IS NOT NULL THEN mpg.grupo
      WHEN LOWER(pi.nice_name) LIKE '%plan-a%' THEN 'plan-a'
      WHEN LOWER(pi.nice_name) LIKE '%plan-b%' THEN 'plan-b'
      WHEN LOWER(pi.nice_name) LIKE '%plan-c%' THEN 'plan-c'
      WHEN LOWER(pi.nice_name) LIKE '%plan-free%' THEN 'freemium'
      WHEN LOWER(pi.nice_name) LIKE '%plan-basico%' OR LOWER(pi.nice_name) LIKE '%plano-basico%' THEN 'lojinha'
      WHEN LOWER(pi.nice_name) LIKE '%enterprise%' OR LOWER(pi.nice_name) LIKE '%empresarial%' THEN 'enterprise'
      ELSE 'unknown'
    END AS grupo,
    
    -- Before freemium launch flag (lógica original)
    CASE 
      WHEN pc.plan_countries_id IN (681,682,683,684) THEN 0
      WHEN pc.plan_countries_id <= 2575 THEN 1
      ELSE 0
    END AS before_freemium_launch,
    
    -- Plan user-facing name: priorizar data_manual, fallback a lógica por país
    COALESCE(
      mpg.namev2,  -- Si existe en data_manual, usar ese
      -- Fallback logic por grupo y país (igual que operations_grouping_plans.sql)
      CASE
        WHEN COALESCE(mpg.grupo, 
                     CASE
                       WHEN LOWER(pi.nice_name) LIKE '%enterprise%' THEN 'enterprise'
                       WHEN LOWER(pi.nice_name) LIKE '%plan-free%' THEN 'freemium'
                       WHEN LOWER(pi.nice_name) LIKE '%basico%' THEN 'lojinha'
                       WHEN LOWER(pi.nice_name) LIKE '%plan-a%' THEN 'plan-a'
                       WHEN LOWER(pi.nice_name) LIKE '%plan-b%' THEN 'plan-b'
                       WHEN LOWER(pi.nice_name) LIKE '%plan-c%' THEN 'plan-c'
                       ELSE 'unknown'
                     END) = 'enterprise' AND pc.country_code IN ('AR', 'CL', 'CO', 'MX') THEN 'evolucion'
        WHEN COALESCE(mpg.grupo, 
                     CASE
                       WHEN LOWER(pi.nice_name) LIKE '%enterprise%' THEN 'enterprise'
                       ELSE NULL
                     END) = 'enterprise' AND pc.country_code = 'BR' THEN 'next'
        -- Freemium por país
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-free%' THEN 'freemium' ELSE NULL END
                     ) = 'freemium' AND pc.country_code = 'AR' THEN 'plan-inicial'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-free%' THEN 'freemium' ELSE NULL END
                     ) = 'freemium' AND pc.country_code = 'BR' THEN 'plan-comeco'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-free%' THEN 'freemium' ELSE NULL END
                     ) = 'freemium' AND pc.country_code = 'MX' THEN 'plan-gratis'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-free%' THEN 'freemium' ELSE NULL END
                     ) = 'freemium' AND pc.country_code = 'CL' THEN 'freemium'
        -- Lojinha (igual para todos los países)
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%basico%' THEN 'lojinha' ELSE NULL END
                     ) = 'lojinha' THEN 'plan-basico'
        -- Plan A por país
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-a%' THEN 'plan-a' ELSE NULL END
                     ) = 'plan-a' AND pc.country_code IN ('AR', 'CO') THEN 'plan-esencial'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-a%' THEN 'plan-a' ELSE NULL END
                     ) = 'plan-a' AND pc.country_code = 'BR' THEN 'plan-essencial'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-a%' THEN 'plan-a' ELSE NULL END
                     ) = 'plan-a' AND pc.country_code = 'CL' THEN 'plan-full'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-a%' THEN 'plan-a' ELSE NULL END
                     ) = 'plan-a' AND pc.country_code = 'MX' THEN 'plan-basico'
        -- Plan B por país
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-b%' THEN 'plan-b' ELSE NULL END
                     ) = 'plan-b' AND pc.country_code IN ('AR', 'CO', 'BR') THEN 'plan-impulso'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-b%' THEN 'plan-b' ELSE NULL END
                     ) = 'plan-b' AND pc.country_code = 'CL' THEN 'plan-plus'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-b%' THEN 'plan-b' ELSE NULL END
                     ) = 'plan-b' AND pc.country_code = 'MX' THEN 'plan-tiendanube'
        -- Plan C por país
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-c%' THEN 'plan-c' ELSE NULL END
                     ) = 'plan-c' AND pc.country_code IN ('AR', 'BR', 'CO') THEN 'plan-escala'
        WHEN COALESCE(mpg.grupo, 
                     CASE WHEN LOWER(pi.nice_name) LIKE '%plan-c%' THEN 'plan-c' ELSE NULL END
                     ) = 'plan-c' AND pc.country_code IN ('CL', 'MX') THEN 'plan-avanzado'
        -- Zero fee
        WHEN COALESCE(mpg.grupo, 'unknown') = 'zero-fee' THEN 'colaboradores'
        ELSE 'unknown'
      END
    ) AS namev2
    
  FROM plans_countries pc
  LEFT JOIN plans_info pi ON pc.plan_id = pi.plan_id
  LEFT JOIN manual_plan_groups mpg ON pc.plan_countries_id = mpg.plan_countries_id
),

-- Group dimension with order (replicando dim_group_plan logic)
group_dimension AS (
  SELECT 
    grupo AS group_name,
    namev2 AS group_desc,
    CASE 
      WHEN grupo IN ('test_broken','no-stores') THEN 0
      WHEN grupo IN ('zero-fee','freemium') THEN 1
      WHEN grupo IN ('lojinha','plan-a','plan-emprendedor') THEN 2
      WHEN grupo IN ('plan-b') THEN 3
      WHEN grupo IN ('plan-c') THEN 4
      WHEN grupo IN ('enterprise') THEN 5
      ELSE -1 
    END AS group_order_id,
    COLLECT_LIST(plan_countries_id) AS plan_id_nk_array
  FROM plan_group_classification
  GROUP BY grupo, namev2
),

-- Final plan mapping para tiendas
final_plan_mapping AS (
  SELECT 
    bs.store_id,
    bs.plan_id_nk,
    bs.country_code,
    pgc.grupo AS group_name,
    pgc.namev2 AS group_desc,
    pgc.before_freemium_launch,
    -- Group order desde dimension
    gd.group_order_id
  FROM base_stores bs
  LEFT JOIN plans_countries pc ON bs.plan_id_nk = pc.plan_countries_id
  LEFT JOIN plan_group_classification pgc ON pc.plan_countries_id = pgc.plan_countries_id
  LEFT JOIN group_dimension gd ON pgc.grupo = gd.group_name AND pgc.namev2 = gd.group_desc
  
  -- Excluir plans específicos según lógica del modelo original
  WHERE NOT (pgc.grupo IN ('test_broken', 'no-stores') OR pgc.plan_countries_id IN (20, 21))
)

-- Query final
SELECT 
  store_id,
  plan_id_nk,
  
  -- Group info (nombres que usa marketing_merchant_info_refined)
  COALESCE(group_name, 'unknown') AS group_name,
  COALESCE(group_desc, 'unknown') AS group_desc, 
  COALESCE(group_order_id, -1) AS group_order_id,
  
  -- Metadata
  before_freemium_launch,
  country_code

FROM final_plan_mapping
ORDER BY store_id

-- NOTA: Esta query usa la tabla real hive_metastore.data_manual.operations__grouping_plans_aux
-- para mapear los plans a groups. Para plans que no están en la tabla manual,
-- aplica fallback logic basada en nice_name igual que el modelo DBT original.
