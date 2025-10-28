{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['order_id'],
        on_schema_change='fail',
        partition_by=['year_month_day_code'],
        tags=["daily-9am"]
    )
}}

SELECT
order_id,
total,
gateway_method,
gateway,
gateway_handle,
gateway_integration_type,
status,
total_in_usd,
order_completed_at,
order_cancelled_at,
payment_status,
fulfillment_status,
plan,
cancel_reason,
store_id,
domain,
country,
state,
current_segment,
year_month_day_code,
storefront,
coupon_discount,
gateway_discount,
promo_discount,
shipping_discount,
stock_issues,
integration,
shipping_method,
order_type,
total_ffoo,
current_timestamp AS sys_audit_created_on,
'data-dev-dbt-products' AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__orders_1y') }} o
   {% if is_incremental() %}
WHERE o.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}
