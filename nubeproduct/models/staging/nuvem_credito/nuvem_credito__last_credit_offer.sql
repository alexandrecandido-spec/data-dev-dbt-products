{{
    config(
        materialized='table',
        unique_key='store_id',
        on_schema_change='fail',
        tags=["fintech", "daily-4am"]
    )
}}

WITH 

offers AS (
SELECT 
       CAST(lead_external_id AS INT) AS store_id,
       available_limit / 100 AS available_limit,
       closed_at,
       ROW_NUMBER() OVER (PARTITION BY lead_external_id ORDER BY created_at DESC) AS rank
  FROM {{ source('stg_nuvem_credito', 'offers') }}
)

SELECT 
       store_id,
       available_limit,
       closed_at,
       'data-dev-dbt-products' AS sys_audit_created_by,
       CURRENT_TIMESTAMP AS sys_audit_created_on,
       'data-dev-dbt-products' AS sys_audit_updated_by,
       CURRENT_TIMESTAMP AS sys_audit_updated_on
  FROM offers
 WHERE rank = 1