SELECT
       ao.store_id,
       CASE 
         WHEN ao.closed_at IS NULL THEN ao.available_limit
         ELSE 0
       END AS available_limit_admin,
       'data-dev-dbt-products' AS sys_audit_created_by,
       CURRENT_TIMESTAMP AS sys_audit_created_on,
       'data-dev-dbt-products' AS sys_audit_updated_by,
       CURRENT_TIMESTAMP AS sys_audit_updated_on
  FROM {{ ref('nuvem_credito__last_credit_offer') }} ao