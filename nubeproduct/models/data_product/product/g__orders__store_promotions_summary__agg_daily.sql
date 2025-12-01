{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id', 'order_date', 'store_segment', 'current_plan_type', 'country_code'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

SELECT
   --id,
   store_id,
   order_date,
   --total_in_usd,
   --total,
   store_segment,
   current_plan_type,
   country_code,
   --'Coupon' AS promotion_type,
   --audit fields:
    current_timestamp AS sys_audit_created_on,
   'data-dev-dbt-products' AS sys_audit_created_by,
   current_timestamp AS sys_audit_updated_on,
   'data-dev-dbt-products' AS sys_audit_updated_by,
   count(distinct id) as orders,
   sum(total_in_original_currency) as orders_total,
   sum(total_in_usd) as orders_total_usd,
   count(distinct case when has_coupon = true and has_app_coupon = true then id end) as has_app_coupon,
   sum(case when has_coupon = true and has_app_coupon = true then total_in_original_currency end) as has_app_coupon_total,
   sum(case when has_coupon = true and has_app_coupon = true then total_in_usd end) as has_app_coupon_total_usd,
   count(distinct case when has_coupon = true and has_app_coupon = false then id end) as has_native_coupon,
   sum(case when has_coupon = true and has_app_coupon = false then total_in_original_currency end) as has_native_coupon_total,
   sum(case when has_coupon = true and has_app_coupon = false then total_in_usd end) as has_native_coupon_total_usd,
   count(distinct case when has_free_shipping = TRUE then id end) as has_free_shipping,
   sum(case when has_free_shipping = TRUE then total_in_original_currency end) as has_free_shipping_total,
   sum(case when has_free_shipping = TRUE then total_in_usd end) as has_free_shipping_total_usd,
   count(distinct case when has_free_custom_shipping = TRUE then id end) as has_free_custom_shipping,
   sum(case when has_free_custom_shipping = TRUE then total_in_original_currency end) as has_free_custom_shipping_total,
   sum(case when has_free_custom_shipping = TRUE then total_in_usd end) as has_free_custom_shipping_total_usd,
   count(distinct case when has_free_shipping_coupon = TRUE then id end) as has_free_shipping_coupon,
   sum(case when has_free_shipping_coupon = TRUE then total_in_original_currency end) as has_free_shipping_coupon_total,
   sum(case when has_free_shipping_coupon = TRUE then total_in_usd end) as has_free_shipping_coupon_total_usd,
   count(distinct case when has_product_with_free_shipping = TRUE then id end) as has_free_shipping_product,
   sum(distinct case when has_product_with_free_shipping = TRUE then total_in_original_currency end) as has_free_shipping_product_total,
   sum(distinct case when has_product_with_free_shipping = TRUE then total_in_usd end) as has_free_shipping_product_total_usd,
   count(distinct case when has_mxn = TRUE then id end) as has_mxn,
   sum(case when has_mxn = TRUE then total_in_original_currency end) as has_mxn_total,
   sum(case when has_mxn = TRUE then total_in_usd end) as has_mxn_total_usd,
   count(distinct case when has_mxn = true or has_quantity_discount = true then id end) as has_native_discount,
   sum(case when has_mxn = true or has_quantity_discount = true then total_in_original_currency end) as has_native_discount_total,
   sum(case when has_mxn = true or has_quantity_discount = true then total_in_usd end) as has_native_discount_total_usd,
   count(distinct case when has_quantity_discount = TRUE then id end) as has_quantity_discount,
   sum(case when has_quantity_discount = TRUE then total_in_original_currency end) as has_quantity_discount_total,
   sum(case when has_quantity_discount = TRUE then total_in_usd end) as has_quantity_discount_total_usd,
   count(distinct case when has_payment_method_discount = TRUE then id end) as has_payment_method_discount,
   sum(case when has_payment_method_discount = TRUE then total_in_original_currency end) as has_payment_method_discount_total,
   sum(case when has_payment_method_discount = TRUE then total_in_usd end) as has_payment_method_discount_total_usd,
   count(distinct case when has_application_discount = TRUE then id end) as has_application_discount,
   sum(case when has_application_discount = TRUE then total_in_original_currency end) as has_application_discount_total,
   sum(case when has_application_discount = TRUE then total_in_usd end) as has_application_discount_total_usd,
   --
   count(distinct case when (has_coupon = true and has_app_coupon = false) or has_mxn = true or has_quantity_discount = true
        or has_free_shipping = true or has_free_custom_shipping = true or has_free_shipping_coupon = true
        or has_product_with_free_shipping = true or has_payment_method_discount = TRUE then id end) as has_native_gmv,
   sum(case when (has_coupon = true and has_app_coupon = false) or has_mxn = true or has_quantity_discount = true
        or has_free_shipping = true or has_free_custom_shipping = true or has_free_shipping_coupon = true
        or has_product_with_free_shipping = true or has_payment_method_discount = TRUE then total_in_original_currency end) as has_native_gmv_total,
   sum(case when (has_coupon = true and has_app_coupon = false) or has_mxn = true or has_quantity_discount = true
        or has_free_shipping = true or has_free_custom_shipping = true or has_free_shipping_coupon = true
        or has_product_with_free_shipping = true or has_payment_method_discount = TRUE then total_in_usd end) as has_native_gmv_total_usd,
   count(distinct case when has_free_custom_shipping = true or has_free_shipping_coupon = true
        or has_product_with_free_shipping = true then id end) as has_native_free_shipping_gmv,
   sum(case when has_free_custom_shipping = true or has_free_shipping_coupon = true
        or has_product_with_free_shipping = true then total_in_original_currency end) as has_native_free_shipping_gmv_total,
   sum(case when has_free_custom_shipping = true or has_free_shipping_coupon = true
        or has_product_with_free_shipping = true then total_in_usd end) as has_native_free_shipping_gmv_total_usd,
   --
   count(distinct case when NOT (
   has_coupon OR
   has_free_shipping OR
   has_free_custom_shipping OR
   has_free_shipping_coupon OR
   has_product_with_free_shipping OR
   has_mxn OR
   has_quantity_discount OR
   has_payment_method_discount OR
   has_application_discount) then id end) as no_promotion,
   sum(case when NOT (
   has_coupon OR
   has_free_shipping OR
   has_free_custom_shipping OR
   has_free_shipping_coupon OR
   has_product_with_free_shipping OR
   has_mxn OR
   has_quantity_discount OR
   has_payment_method_discount OR
   has_application_discount) then total_in_original_currency end) as no_promotion_total,
   sum(case when NOT (
   has_coupon OR
   has_free_shipping OR
   has_free_custom_shipping OR
   has_free_shipping_coupon OR
   has_product_with_free_shipping OR
   has_mxn OR
   has_quantity_discount OR
   has_payment_method_discount OR
   has_application_discount) then total_in_usd end) as no_promotion_total_usd,
   count(distinct case when (
   has_coupon OR
   has_free_shipping OR
   has_free_custom_shipping OR
   has_free_shipping_coupon OR
   has_product_with_free_shipping OR
   has_mxn OR
   has_quantity_discount OR
   has_payment_method_discount OR
   has_application_discount) then id end) as has_promotion,
   sum(case when (
   has_coupon OR
   has_free_shipping OR
   has_free_custom_shipping OR
   has_free_shipping_coupon OR
   has_product_with_free_shipping OR
   has_mxn OR
   has_quantity_discount OR
   has_payment_method_discount OR
   has_application_discount) then total_in_original_currency end) as has_promotion_total,
   sum(case when (
   has_coupon OR
   has_free_shipping OR
   has_free_custom_shipping OR
   has_free_shipping_coupon OR
   has_product_with_free_shipping OR
   has_mxn OR
   has_quantity_discount OR
   has_payment_method_discount OR
   has_application_discount) then total_in_usd end) as has_promotion_total_usd
FROM {{ref('_int__orders__store_promotions_summary')}} source

{% if is_incremental() %}
WHERE source.sys_audit_updated_on >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01')
    FROM {{ this }}
)
{% endif %}
group by 1,2,3,4,5