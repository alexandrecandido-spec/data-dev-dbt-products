{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['line_edit_id'],
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}

select distinct
    msi.store_id,
    msi.country,
    mp.nice_name plan_name,
    t.has_edit_orders_disponible,
    t.fecha_edit_orders_disponible,
    o.year_month_day_code,
    o.id,
    o.fecha_completed_at,
    o.payment_status,
    o.status,
    o.gmv_usd,
    oe.id edit_id,
    oe.skip_shipping_requote,
    cast(coalesce(ae.happened_at,oe.happened_at) as date) edit_at,
    vh.previous_total,
    vh.total_delta,
    vh.previous_total_usd,
    vh.total_delta_usd,
    vh.previous_subtotal,
    vh.subtotal_delta,
    vh.previous_subtotal_usd,
    vh.subtotal_delta_usd,
    ae.id as line_edit_id,
    ae.extra,
    ae.edit_type,
    ae.edit_action,
    ae.amount, 
    ae.amount_usd,
    ae.line_item_id,
    ae.previous_product_qty,
    ae.new_product_qty,
    s.previous_merchant_cost,
    s.new_merchant_cost,
    s.previous_consumer_cost,
    s.new_consumer_cost,
    s.previous_merchant_cost_usd,
    s.new_merchant_cost_usd,
    s.previous_consumer_cost_usd,
    s.new_consumer_cost_usd,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    FROM {{ ref('moltres__mwp_store_info') }} msi
    LEFT JOIN {{ source('dp_moltres', 'mwp_plans_countries') }}  mpc ON mpc.id = msi.plan
    LEFT JOIN {{ source('dp_moltres', 'mwp_plans') }}  mp ON mpc.plan = mp.id 
    LEFT JOIN {{ ref('_int_product__edit_orders_enabling_tag') }} t on t.related_id = msi.store_id
    LEFT JOIN {{ ref('_int_product__edit_orders_orders') }} o on o.store_id = msi.store_id
    LEFT JOIN {{ ref('_int_product__edit_orders_union_edit_types') }} ae on o.id = ae.order_id
    LEFT JOIN {{ source('edit_history_and_requotes', 'orders_edit_history') }} oe on oe.id = ae.edit_id
    LEFT JOIN {{ source('edit_history_and_requotes', 'orders_edit_history_shipping') }} s on s.edit_id = ae.edit_id
    LEFT JOIN {{ ref('_int_product__edit_orders_value_history') }} vh on vh.id = oe.order_value_history_id
    {% if is_incremental() %}
    WHERE 
     msi.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    or mpc.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    or mp.sys_audit_updated_at >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    or o.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    or oe.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    or s.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}