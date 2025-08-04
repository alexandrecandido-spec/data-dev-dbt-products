WITH contract_ranks AS (
  SELECT 
    mc.store_id,
    mc.plan_id,
    pg.grupo,
    mc.created_at AS contract_date,
    mc.type AS contract_type,
    mc.total,
    ROW_NUMBER() OVER (
      PARTITION BY mc.store_id 
      ORDER BY mc.created_at DESC
    ) AS rn
  FROM {{ ref('moltres__contracts') }} mc
  LEFT JOIN {{ ref('operations_grouping_plans') }} pg 
    ON pg.plan = mc.plan_id
  LEFT JOIN {{ ref('moltres__mwp_store_info') }} si 
    ON mc.store_id = si.store_id
  WHERE mc.start_date < si.first_payment and type in ('freemium', 'trial')
)

SELECT *
FROM contract_ranks
WHERE rn = 1
