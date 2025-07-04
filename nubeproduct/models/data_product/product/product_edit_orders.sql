{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['edit_action_id'],
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}

select distinct
    store_id,
    country,
    state,
    churned_at,
    plan_name,
    has_edit_orders_disponible,
    fecha_edit_orders_disponible,
    year_month_day_code,
    id,
    fecha_completed_at,
    payment_status,
    status,
    gmv_usd,
    edit_id,
    skip_shipping_requote,
    edit_at,
    previous_total,
    total_delta,
    previous_total_usd,
    total_delta_usd,
    previous_subtotal,
    subtotal_delta,
    previous_subtotal_usd,
    subtotal_delta_usd,
    line_edit_id,
    edit_action_id,
    extra,
    edit_type,
    edit_action,
    amount, 
    amount_usd,
    line_item_id,
    fulfillment_order_id,
    previous_product_qty,
    new_product_qty,
    previous_merchant_cost,
    new_merchant_cost,
    previous_consumer_cost,
    new_consumer_cost,
    previous_merchant_cost_usd,
    new_merchant_cost_usd,
    previous_consumer_cost_usd,
    new_consumer_cost_usd,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    FROM {{ ref('_int_product__edit_orders_int_joins') }}  j
    {% if is_incremental() %}
    WHERE 
     j.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}