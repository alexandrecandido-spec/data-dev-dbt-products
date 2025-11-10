WITH ffoo as (
    SELECT 
    store_id,
    order_id,
    max(sys_audit_updated_on) as max_sys_audit_updated_on,
    count(distinct id) as total_ffoo,
    count(distinct case when shipping_type = 'non-shippable' then id end) as digital,
    count(distinct case when shipping_type = 'pickup' and shippable = false then id end) as store_pickup,
    count(distinct case when shipping_type = 'ship' then id end) as shipping,
    count(distinct case when shipping_type = 'pickup' and (shippable = true or shippable is null) then id end) as location_pickup,
    bool_or(case when (shippable = true or shippable is null) and shipping_type = 'pickup' and status = 'READY_FOR_PICKUP' then true end) as has_ready_for_pickup_ffoo
    from {{ref('product__orders__fulfillment_orders__event')}}
    group by 1,2
),

timestamps as (
    SELECT
    store_id,
    order_id,
    MAX(case when type = 'order-status' and data_2 = 'open'then true else false end) as has_open,
    max(sys_audit_updated_on) as max_sys_audit_updated_on,
    max(case when data_2 = 'paid' then happened_at end) paid_at,
    max(case when data_2 = 'unpacked' then happened_at end) unpacked_at,
    max(case when data_2 = 'partially_packed' then happened_at end) partially_packed_at,
    max(case when data_2 = 'unfulfilled' then happened_at end) unfulfilled_at,
    max(case when data_2 = 'partially_fulfilled' then happened_at end) partially_fulfilled_at,
    max(case when data_2 = 'fulfilled' then happened_at end) fulfilled_at,
    max(case when data_2 = 'delivered' then happened_at end) delivered_at
    from {{ ref('product__orders__order_logging__event') }}
    group by 1,2
)

SELECT
o.id order_id,
o.total,
o.gateway_method,
o.gateway_integration_type,
t.has_open,
o.gateway,
apps.handle as gateway_handle,
o.status,
o.total_in_usd,
datediff(SECOND,completed_at,paid_at) as completed_to_paid_time,
datediff(SECOND,paid_at,unfulfilled_at) as paid_to_unfulfilled_time,
datediff(SECOND,completed_at,unfulfilled_at) as completed_to_unfulfilled_time,
datediff(SECOND,completed_at,fulfilled_at) as completed_to_fulfilled_time,
datediff(SECOND,unfulfilled_at,fulfilled_at) as unfulfilled_to_fulfilled_time,
datediff(SECOND,fulfilled_at,delivered_at) as fulfilled_to_delivered_time,
datediff(SECOND,completed_at,delivered_at) as completed_to_delivered_time,
date(o.completed_at) order_completed_at,
date(o.cancelled_at) as order_cancelled_at,
date(t.paid_at) as order_paid_at,
date(t.unpacked_at) as order_unpacked_at,
date(t.partially_packed_at) as order_partially_packed_at,
date(t.unfulfilled_at) as order_unfulfilled_at,
date(t.partially_fulfilled_at) as order_partially_fulfilled_at,
date(t.fulfilled_at) as order_fulfilled_at,
date(t.delivered_at) as order_delivered_at,
payment_status,
fulfillment_status,
gp.grupo as plan,
o.cancel_reason,
o.store_id,
i.domain,
i.country,
i.state,
i.first_payment,
i.churned_at,
i.created_at,
i.current_segment,
o.year_month_day_code,
case when o.internal_extra like '%stock_issue%' then true else false end as stock_issues,
o.storefront,
o.discount coupon_discount,
o.discount_gateway gateway_discount,
o.promotional_discount_id promo_discount,
abs(o.shipping_cost_owner - o.shipping_cost) as shipping_discount,
CASE 
	WHEN shipping_method LIKE 'api_%' THEN concat('App - ', sc.shipping_carrier_name)
	WHEN shipping_method LIKE '%table%' AND shipping_pickup_type = 'ship' THEN 'Personalizado: envio'
	WHEN shipping_method LIKE '%table%' AND shipping_pickup_type = 'pickup' THEN 'Personalizado: retiro'
    WHEN (shipping_method LIKE 'branch') THEN 'Retiro tienda fisica'
    WHEN (shipping_method LIKE 'pickup-point') THEN 'Puntos de retiro (new)'
	WHEN shipping_method LIKE 'draft' THEN 'Draft order'
	WHEN shipping_method IS NULL THEN 'Without shipping data'
	WHEN shipping_method = 'multiple' THEN 'Multiples (MultiCD)'
	WHEN shipping_method = 'fallback' THEN 'Fallback'
	ELSE concat('Core - ', shipping_method) 
END AS shipping_method,
CASE 
	WHEN shipping_method LIKE 'api_%' THEN 'App integration'
	WHEN shipping_method LIKE '%table%' AND shipping_pickup_type = 'ship' THEN 'Personalizado: envio'
	WHEN shipping_method LIKE '%table%' AND shipping_pickup_type = 'pickup' THEN 'Personalizado: retiro'
        WHEN (shipping_method LIKE 'branch') THEN 'Retiro tienda fisica'
        WHEN (shipping_method LIKE 'pickup-point') THEN 'Puntos de retiro (new)'
	WHEN shipping_method LIKE 'draft' THEN 'Draft order'
	WHEN shipping_method IS NULL THEN 'Without shipping data'
	WHEN shipping_method = 'multiple' THEN 'Multiples (MultiCD)'
	WHEN shipping_method = 'fallback' THEN 'Fallback'
	ELSE 'Core integration'
END AS integration, 
case when total_ffoo = digital then 'digital order'
else case when total_ffoo=store_pickup then 'pickup order'
else case when total_ffoo=shipping and total_ffoo=1 then 'shipping order'
else case when total_ffoo=shipping and total_ffoo>1 then 'multiple shipping order'
else case when total_ffoo=location_pickup then 'location_pickup_order'
else case when total_ffoo=0 then 'no ffoo'
else 'combined order'
end end end end end end as order_type,
total_ffoo,
has_ready_for_pickup_ffoo,
GREATEST(
    o.sys_audit_updated_on,
    i.sys_audit_updated_on,
    gp.sys_audit_updated_on,
    apps.sys_audit_updated_on,
    ffoo.max_sys_audit_updated_on,
    t.max_sys_audit_updated_on
) as max_sys_audit_updated_on
from {{ ref('orders__mwp_orders') }}  o
left join {{ ref('moltres__mwp_store_info') }} i on i.store_id = o.store_id
left join {{ ref('operations_grouping_plans') }} gp on gp.plan = i.plan
left join {{ ref('moltres__mwp_apps') }} apps on concat('app_',apps.id) = o.gateway
left join {{ ref('product__shipping__shipping_carriers__event')}} sc ON o.shipping_method = concat('api_', sc.shipping_carrier_id)
left join ffoo ON o.id = ffoo.order_id and o.store_id = ffoo.store_id
left join timestamps t ON o.id = t.order_id and o.store_id = t.store_id
where
TO_DATE(cast(year_month_day_code as string), 'yyyyMMdd') >= DATE_SUB(current_date(), 365)
and completed_at is not null 