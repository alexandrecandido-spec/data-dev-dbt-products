{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['saved_search_id'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

select
    saved_search_id,
    store_id,
    state,
    country,
    currency,
    current_segment,
    first_payment,
    churned_at,
    plan_name,
    merchant_created_at,
    saved_search_user_id,
    saved_search_name,
    saved_search_position,
    saved_search_default,
    saved_search_hidden,
    saved_search_created_at,
    saved_search_number_of_keys,
    saved_search_page,
    saved_search_q,
    saved_search_per_page,
    saved_search_date_from,
    saved_search_date_to,
    saved_search_status,
    saved_search_payment_status,
    saved_search_fulfillment_status,
    saved_search_payment_methods,
    saved_search_payment_provider,
    saved_search_shipping_method,
    saved_search_location,
    saved_search_origin,
    saved_search_appId,
    saved_search_products,
    saved_search_exact_product_set,
    saved_search_min_units,
    saved_search_max_units,
    saved_search_is_wholesale,
    saved_search_coupon_ids_raw,
    saved_search_stock_issues,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__orders_saved_searches') }} s
    {% if is_incremental() %}
WHERE s.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}
