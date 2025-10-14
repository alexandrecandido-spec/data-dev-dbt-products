{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        unique_key='company_id',
        on_schema_change='fail'
    )
}}

SELECT
	cast(company_id as integer) as company_id, --lo casteo porque estaba como string
    cast(store_id as integer) as store_id, --lo casteo porque estaba como string
	current_timestamp AS sys_audit_created_on,
	'data-dev-dbt-products' AS sys_audit_created_by,
	current_timestamp AS sys_audit_updated_on,
	'data-dev-dbt-products' AS sys_audit_updated_by
FROM
	{{ source('stg_hubspot', 'companies') }}

{% if is_incremental() %}

WHERE _airbyte_extracted_at >= 
(select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )

{% endif %}