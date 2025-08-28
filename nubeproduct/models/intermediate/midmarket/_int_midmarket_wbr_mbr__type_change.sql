-- Owner: Guille De Felice

WITH weekly_changes AS (
  SELECT 
    sl.store_id,
    CASE 
      WHEN gp1.grupo != 'enterprise' AND gp2.grupo = 'enterprise' THEN 'upsell'
      WHEN gp1.grupo = 'enterprise' AND gp2.grupo != 'enterprise' THEN 'downgrade'
    END AS type_change,
    'weekly' AS periodicity,
    ROW_NUMBER() OVER (PARTITION BY sl.store_id ORDER BY sl.created_at DESC) AS rn
  FROM {{ source('int_storefronts_curated', 'mwp_stores_logging') }} sl
  INNER JOIN {{ ref('midmarket_success_stores') }} s
    ON sl.store_id = s.store_id
  LEFT JOIN {{ ref('operations_grouping_plans') }} gp1
    ON sl.data_1 = gp1.plan
  LEFT JOIN {{ ref('operations_grouping_plans') }} gp2
    ON sl.data_2 = gp2.plan
  WHERE 
    sl.type = 'plan-change'
    AND sl.created_at >= date_add(DAY, -7, date_trunc('week', current_date))
    AND sl.created_at < date_trunc('week', current_date)
),

monthly_changes AS (
  SELECT 
    sl.store_id,
    CASE 
      WHEN gp1.grupo != 'enterprise' AND gp2.grupo = 'enterprise' THEN 'upsell'
      WHEN gp1.grupo = 'enterprise' AND gp2.grupo != 'enterprise' THEN 'downgrade'
    END AS type_change,
    'monthly' AS periodicity,
    ROW_NUMBER() OVER (PARTITION BY sl.store_id ORDER BY sl.created_at DESC) AS rn
  FROM {{ source('int_storefronts_curated', 'mwp_stores_logging') }} sl
  INNER JOIN {{ ref('midmarket_success_stores') }} s
    ON sl.store_id = s.store_id
  LEFT JOIN {{ ref('operations_grouping_plans') }} gp1
    ON sl.data_1 = gp1.plan
  LEFT JOIN {{ ref('operations_grouping_plans') }} gp2
    ON sl.data_2 = gp2.plan
  WHERE 
    sl.type = 'plan-change'
    AND sl.created_at >= date_trunc('month', current_date - interval '1' month)
    AND sl.created_at < date_trunc('month', current_date)
)

SELECT 
    store_id, 
    type_change, 
    periodicity
FROM weekly_changes
WHERE 
    rn = 1

UNION ALL

SELECT 
    store_id, 
    type_change, 
    periodicity
FROM monthly_changes
WHERE 
    rn = 1