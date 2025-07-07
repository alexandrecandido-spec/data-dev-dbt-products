select distinct
    msi.store_id,
    msi.country,
    msi.state,
    cast(msi.churned_at as date) as churned_at,
    mp.nice_name plan_name,
    t.has_edit_orders_disponible,
    t.fecha_edit_orders_disponible,
    o.year_month_day_code,
    o.id,
    o.fecha_completed_at,
    o.payment_status,
    o.status,
    o.gmv_usd,
    coalesce(oe.id,ae.edit_id) edit_id,
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
    concat(ae.id,ae.edit_type,s.fulfillment_order_id) as edit_action_id,
    ae.line_item_id,
    ae.previous_product_qty,
    ae.new_product_qty,
    s.fulfillment_order_id,
    s.previous_merchant_cost,
    s.new_merchant_cost,
    s.previous_consumer_cost,
    s.new_consumer_cost,
    s.previous_merchant_cost_usd,
    s.new_merchant_cost_usd,
    s.previous_consumer_cost_usd,
    s.new_consumer_cost_usd,
    oe.sys_audit_updated_on
    FROM {{ ref('moltres__mwp_store_info') }} msi
    LEFT JOIN {{ source('int_moltres', 'mwp_plans_countries') }}  mpc ON mpc.id = msi.plan
    LEFT JOIN {{ source('int_moltres', 'mwp_plans') }}  mp ON mpc.plan = mp.id 
    LEFT JOIN {{ ref('_int_product__edit_orders_enabling_tag') }} t on t.related_id = msi.store_id
    LEFT JOIN {{ ref('_int_product__edit_orders_orders') }} o on o.store_id = msi.store_id
    LEFT JOIN {{ ref('_int_product__edit_orders_union_edit_types') }} ae on o.id = ae.order_id
    LEFT JOIN {{ source('int_orders', 'orders_edit_history') }} oe on oe.id = ae.edit_id
    LEFT JOIN {{ source('int_orders', 'orders_edit_history_shipping') }} s on s.edit_id = ae.edit_id
    LEFT JOIN {{ ref('_int_product__edit_orders_value_history') }} vh on vh.id = oe.order_value_history_id
