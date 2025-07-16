{{
    config(
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=["daily-7am"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)
SELECT
 i.store_id
,i.country
,CASE WHEN s.type IS NULL THEN
      CASE WHEN v.vertifier IS NULL THEN 'undefined'
           WHEN v.vertifier  IN ('','unknown') THEN 'undefined' 
           ELSE v.vertifier 
      END 
      ELSE s.type END AS vertical,
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM      {{ ref('moltres__mwp_store_info') }} i 
LEFT JOIN {{ source('dp_moltres','mwp_store_settings') }} s ON s.store_id = i.store_id
LEFT JOIN {{ ref('_int_company_metrics_merchant_vertical_partition_by') }} v ON v.store_id = i.store_id
LEFT JOIN existing_data e on e.store_id = i.store_id