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
    msi.id store_id,
    msi.country,
    msi."domain",
    mp.nice_name plan_name,
    msi.current_segment,
    msi.max_segment,
    t.has_edit_orders_disponible,
    t.fecha_edit_orders_disponible,
    o.year_month_day_code,
    o.order_id,
    o.fecha_completed_at,
    o.payment_status,
    o.status,
    o.gmv_usd,
    o.coupon_discount,
    o.gateway_discount,
    o.promo_discount,
    abs(o.shipping_cost_owner - o.shipping_cost) shipping_discount,
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
    edit_type,
    edit_action,
    amount, 
    amount_usd,
    line_item_id,
    previous_product_qty,
    new_product_qty,
    s.previous_merchant_cost,
    s.new_merchant_cost,
    s.previous_consumer_cost,
    s.new_consumer_cost,
    s.previous_merchant_cost_usd,
    s.new_merchant_cost_usd,
    s.previous_consumer_cost_usd,
    s.new_consumer_cost_usd
    FROM {{ ref('moltres__mwp_store_info') }} msi
    LEFT JOIN {{ source('dp_moltres', 'mwp_plans_countries') }}  mpc ON mpc.id = msi.plan
    LEFT JOIN {{ source('dp_moltres', 'mwp_plans') }}  mp ON mpc.plan = mp.id 
    LEFT JOIN {{ ref('_int_product__edit_orders_enabling_tag') }} t on t.store_id = msi.id
    LEFT JOIN {{ ref('_int_product__edit_orders_orders') }} o on o.store_id = msi.id
        LEFT JOIN {{ ref('_int_product__edit_orders_union_edit_types') }} ae on o.id = ae.order_id
    LEFT JOIN {{ source('edit_history_and_requotes', 'orders_edit_history') }} oe on oe.id = ae.edit_id
    LEFT JOIN {{ source('edit_history_and_requotes', 'orders_edit_history_shipping') }} s on s.edit_id = ae.edit_id
    LEFT JOIN {{ ref('_int_product__edit_orders_value_history') }} vh on vh.id = oe.order_value_history_id
    {% if is_incremental() %}
    WHERE 
        l.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or v.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or i.sys_audit_updated_at >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or s.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or onb.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or w1.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or w2.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or w3.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or w4.sys_audit_updated_on >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or mi.sys_audit_updated_at >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or db.sys_audit_updated_at >= (select coalesce(max(a.sys_audit_updated_on),'1900-01-01') from {{ this }} a )
    {% endif %}