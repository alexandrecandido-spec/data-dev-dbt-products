{{
    config(
        tags = ["product","daily-morning"],
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail'
    )
}}

SELECT
	id,
	order_id,
	price_table_id,
	percentage_applied,
	current_timestamp AS sys_audit_created_on,
	'data-dev-dbt-products' AS sys_audit_created_by,
	current_timestamp AS sys_audit_updated_on,
	'data-dev-dbt-products' AS sys_audit_updated_by
FROM
	{{ source('stg_orders', 'mwp_orders_b2b') }}

{% if is_incremental() %}

WHERE sys_audit_updated_on >= 
(select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )

{% endif %}