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
        --unique id
    edit_action_id,
    --data on edit action
    line_edit_id,
    extra,
    edit_type,
    edit_action,
    amount, 
    amount_usd,
    line_item_id,
    previous_product_qty,
    new_product_qty,
    --data on edit
    edit_id,
    edit_at,
    --data on total values and shipping costs
    skip_shipping_requote,
    previous_total,
    total_delta,
    previous_total_usd,
    total_delta_usd,
    previous_subtotal,
    subtotal_delta,
    previous_subtotal_usd,
    subtotal_delta_usd,
    fulfillment_order_id,
    previous_merchant_cost,
    new_merchant_cost,
    previous_consumer_cost,
    new_consumer_cost,
    previous_merchant_cost_usd,
    new_merchant_cost_usd,
    previous_consumer_cost_usd,
    new_consumer_cost_usd,
    --data on order
    id,
    fecha_completed_at,
    payment_status,
    status,
    gmv_usd,
    year_month_day_code,
    was_order_edited,
    order_first_edited_at,
    order_last_edited_at,
    order_edit_count,
    --data on store
    store_id,
    state,
    country,
    currency,
    current_segment,
    first_payment,
    churned_at,
    grupo,
    created_at,
    verified,
    store_has_edit_orders_disponible,
    store_fecha_edit_orders_disponible,
    store_edit_orders_user,
    store_edit_first_use,
    store_edit_last_use,
    store_edit_count,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    FROM {{ ref('_int_product__edit_orders_int_joins') }}  j
    {% if is_incremental() %}
    WHERE 
     j.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}