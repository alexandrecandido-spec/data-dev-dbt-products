{{
    config(
        tags=["daily-morning"]
    )
}}

SELECT
    b2b.id,
	o.id as order_id,
    si.store_id,
    si.domain,
    si.country,
    si.state,
    gp.grupo as plan,
	b2b.price_table_id,
	b2b.percentage_applied,
    o.completed_at,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('orders__mwp_orders_b2b') }} b2b
JOIN {{ ref('orders__mwp_orders') }} o on b2b.order_id = o.id
JOIN {{ ref('moltres__mwp_store_info') }} si on si.store_id = o.store_id -- excludes stores with state 4
LEFT JOIN {{ ref('operations_grouping_plans') }} gp on gp.plan = si.plan