{{
    config(
        materialized='table',
        unique_key= 'id',
        on_schema_change='fail',
        tags=["logistics","daily-8am"]
    )
}}

SELECT
    id, 
    number AS receipt_number,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('stg_billing', 'receipt') }}