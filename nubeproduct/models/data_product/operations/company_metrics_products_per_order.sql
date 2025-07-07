{{ config(
    materialized = 'incremental',
    unique_key = 'order_id',
    incremental_strategy = 'merge',
    tags=["operations","daily-8am-8pm"]
) }}

WITH orders_to_update (
    SELECT 
        DISTINCT order_id 
    FROM {{ ref('orders__mwp_order_products') }}
    {% if is_incremental() %}
        where change_timestamp > (
            select max(sys_audit_updated_on)
            from {{ this }}
        )
    {% endif %}
),
orders_updated (
    SELECT
        order_id,
        SUM(
            quantity
        ) AS product_quantity
    FROM {{ ref('orders__mwp_order_products') }} products
    {% if is_incremental() %}
        WHERE order_id IN (SELECT order_id FROM orders_to_update)
    {% endif %}
    GROUP BY order_id
),
existing_data AS (
    {{ get_existing_data(this, ['order_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    order.order_id,
    order.product_quantity,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM orders_updated order
LEFT JOIN existing_data e ON order.order_id = e.order_id
