{{
    config(
        tags = ["finance","daily-morning"],
        partition_by = ["year_month_day_code"]
    )
}}

SELECT
	order_id,
	price_table_id,
	percentage_applied,
	current_timestamp AS sys_audit_created_on,
	'data-dev-dbt-products' AS sys_audit_created_by,
	current_timestamp AS sys_audit_updated_on,
	'data-dev-dbt-products' AS sys_audit_updated_by
FROM
	{{ source('stg_orders',
	'mwp_orders_b2b') }}