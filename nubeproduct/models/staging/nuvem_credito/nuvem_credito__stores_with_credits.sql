{{
    config(
        materialized='table',
        unique_key='store_id',
        on_schema_change='fail',
        tags=["fintech", "daily-9am-4pm"]
    )
}}

  SELECT 
        CAST(p.external_id AS INT) AS store_id,
        SUM(CASE WHEN c.status = 'paying' THEN operation_net_amount / 100 ELSE 0 END) AS loan_value,
        'data-dev-dbt-products' AS sys_audit_created_by,
        CURRENT_TIMESTAMP AS sys_audit_created_on,
        'data-dev-dbt-products' AS sys_audit_updated_by,
        CURRENT_TIMESTAMP AS sys_audit_updated_on
  FROM {{ source('stg_nuvem_credito', 'contracts') }} c
  LEFT JOIN {{ source('stg_nuvem_credito', 'payers') }} p
    ON p.id = c.payer_id
  WHERE c.status = 'paying'
    AND p.external_id NOT LIKE '%nuvemshop%'
  GROUP BY CAST(p.external_id AS INT)