{{
    config(
        materialized='table',
        unique_key='partner_id',
        on_schema_change='fail',
        tags=["partnerships", "daily-7am"]
    )
}}
SELECT 
    PI.* ,

    MAX(CASE WHEN SI.partnership_type = 'store_development' THEN 1 ELSE 0 END) AS has_store_dev_trial,
    MAX(CASE WHEN SI.partnership_type = 'affiliate' THEN 1 ELSE 0 END) AS has_affiliates_trial, 
    
    'data-dev-dbt-products' AS sys_audit_created_by,
    CURRENT_TIMESTAMP AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    CURRENT_TIMESTAMP AS sys_audit_updated_on
FROM {{ ref('_int_partnerships__partners_info') }} AS PI
LEFT JOIN {{ ref('_int_partners__agencies_affiliates_stores_store_info') }} AS SI
    ON PI.partner_id = SI.partner_id    
GROUP BY ALL

