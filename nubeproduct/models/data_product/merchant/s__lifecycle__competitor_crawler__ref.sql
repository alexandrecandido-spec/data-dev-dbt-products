{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['id'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

SELECT
id,
store_id,
cname,
competitor,
date,
current_timestamp AS sys_audit_created_on,
'data-dev-dbt-products' AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ source('dp_moltres', 'churned_crawler_store_info') }} o
   {% if is_incremental() %}
WHERE o.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}