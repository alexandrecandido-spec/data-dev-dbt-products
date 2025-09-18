SELECT
       COALESCE(ao.store_id, swc.store_id, al.store_id) AS store_id,
       CASE 
         WHEN ao.closed_at IS NULL THEN ao.available_limit
         ELSE 0
       END AS available_limit_admin,
       CASE 
         WHEN (COALESCE(al.limit, 0) - COALESCE(swc.loan_value, 0)) < 100 THEN 0
         ELSE (COALESCE(al.limit, 0) - COALESCE(swc.loan_value, 0))
       END AS limite_estimado,
       'data-dev-dbt-products' AS sys_audit_created_by,
       CURRENT_TIMESTAMP AS sys_audit_created_on,
       'data-dev-dbt-products' AS sys_audit_updated_by,
       CURRENT_TIMESTAMP AS sys_audit_updated_on
  FROM {{ ref('nuvem_credito__last_credit_offer') }} ao
  FULL OUTER JOIN {{ ref('credito_dev__active_leads') }} al 
               ON ao.store_id = al.store_id
        LEFT JOIN {{ ref('nuvem_credito__stores_with_credits') }} swc 
               ON COALESCE(ao.store_id, al.store_id) = swc.store_id