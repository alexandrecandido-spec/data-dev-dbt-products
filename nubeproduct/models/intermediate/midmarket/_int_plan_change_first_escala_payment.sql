  SELECT 
    mc.store_id,
    CAST(MIN(mc.created_at) AS date) AS first_payment_escala
  FROM {{ source('int_moltres', 'mwp_contracts') }} mc
  JOIN {{ source('int_moltres', 'mwp_store_info') }} i ON mc.store_id = i.id
  LEFT JOIN {{ ref('operations_grouping_plans') }} pg
    ON pg.plan = mc.plan_id
  WHERE i.state<>4 AND pg.grupo='plan-c' AND mc.total>0
  GROUP BY mc.store_id