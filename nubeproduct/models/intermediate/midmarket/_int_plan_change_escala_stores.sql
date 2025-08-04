  SELECT 
    DISTINCT am.store_id
  FROM 
    {{ ref('stg_active_merchants') }} am
  LEFT JOIN {{ ref('operations_grouping_plans') }} pg 
    ON am.store_id_plan_country = pg.plan
  LEFT JOIN {{ ref('moltres__mwp_store_info') }} msi
    ON am.store_id = msi.store_id
  WHERE 
    (pg.grupo = 'plan-c' OR pg.grupo = 'enterprise')
    AND am.store_country IN ('AR','BR','MX') AND
    msi.state <> 4