{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        unique_key='dealbreaker_id',
        on_schema_change='fail'
    )
}}

SELECT
	dealbreaker_id, -- lo casteo porque estaba como string
    type as association_type,
    company_id, -- lo casteo porque estaba como string
	current_timestamp AS sys_audit_created_on,
	'data-dev-dbt-products' AS sys_audit_created_by,
	current_timestamp AS sys_audit_updated_on,
	'data-dev-dbt-products' AS sys_audit_updated_by
FROM
	{{ source('stg_hubspot', 'dealbreakers_companies_associations') }}

{% if is_incremental() %}

WHERE _airbyte_extracted_at >= 
(select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )

{% endif %}