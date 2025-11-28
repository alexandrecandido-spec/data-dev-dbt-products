{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id', 'order_completed_at', 'shipping_method', 'shipping_country_code', 'shipping_country_name', 'is_international_shipping', 'is_same_delivered_status', 'integration'],
        on_schema_change='fail',
        partition_by=['year_month_day_code'],
        tags=['daily-9am']
    )
}}

-- g__shipping__gmv_and_orders__agg_daily

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'order_completed_at', 'shipping_country_code', 'shipping_country_name', 'is_international_shipping', 'is_same_delivered_status', 'integration', 'shipping_method', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    o.store_id,
    o.store_country,
    o.plan_group,
    o.segment,
    o.vertical,
    o.order_completed_at,
    COALESCE(o.shipping_country_code, 'N/D') as shipping_country_code,
    COALESCE(o.shipping_country_name, 'N/D') as shipping_country_name,
    COALESCE(o.is_international_shipping, FALSE) as is_international_shipping,
    COALESCE(o.is_same_delivered_status, 'N/D') as is_same_delivered_status,
    COALESCE(o.shipping_method, 'without shipping data') as shipping_method,
    COALESCE(o.integration, 'without shipping data') as integration,
    o.total_in_usd,
    o.total_orders,
    CAST(date_format(o.order_completed_at, 'yyyyMMdd') AS INTEGER) AS year_month_day_code,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ ref('_int__product__shipping__orders_and_gmv') }} o

LEFT JOIN existing_data e
    ON e.store_id = o.store_id
    AND e.order_completed_at = o.order_completed_at
    and e.shipping_country_code = o.shipping_country_code
    and e.shipping_country_name = o.shipping_country_name
    and e.is_international_shipping = o.is_international_shipping
    and e.is_same_delivered_status = o.is_same_delivered_status
    and e.shipping_method = o.shipping_method
    and e.integration = o.integration