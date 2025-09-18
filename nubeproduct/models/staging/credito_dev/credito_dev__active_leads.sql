{{
    config(
        materialized='table',
        unique_key='store_id',
        on_schema_change='fail',
        tags=["fintech", "daily-9am-4pm"]
    )
}}

SELECT 
       store_id,
       limit,
       'data-dev-dbt-products' AS sys_audit_created_by,
       CURRENT_TIMESTAMP AS sys_audit_created_on,
       'data-dev-dbt-products' AS sys_audit_updated_by,
       CURRENT_TIMESTAMP AS sys_audit_updated_on
  FROM {{ source('stg_credito_dev', 'engine_offers') }}
 WHERE is_active = TRUE
   AND CURRENT_DATE() <= valid_until


  