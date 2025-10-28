WITH ffoo as (
    SELECT 
    store_id,
    order_id,
    max(sys_audit_updated_on) as max_sys_audit_updated_on,
    count(distinct id) as total_ffoo,
    count(distinct case when shipping_type = 'non-shippable' then id end) as digital,
    count(distinct case when shipping_type = 'pickup' and shippable = false then id end) as store_pickup,
    count(distinct case when shipping_type = 'ship' then id end) as shipping,
    count(distinct case when shipping_type = 'pickup' and (shippable = true or shippable is null) then id end) as location_pickup
    from {{ref('product__orders__fulfillment_orders__event')}}
    group by 1,2
)

SELECT
o.id order_id,
o.total,
o.gateway_method,
o.gateway_integration_type,
o.gateway,
apps.handle as gateway_handle,
o.status,
o.total_in_usd,
date(o.completed_at) order_completed_at,
date(o.cancelled_at) as order_cancelled_at,
payment_status,
fulfillment_status,
gp.grupo as plan,
o.cancel_reason,
o.store_id,
i.domain,
i.country,
i.state,
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
else 'combined order'
end end end end end as order_type,
total_ffoo,
GREATEST(
    o.sys_audit_updated_on,
    i.sys_audit_updated_on,
    gp.sys_audit_updated_on,
    apps.sys_audit_updated_on,
    ffoo.max_sys_audit_updated_on
) as max_sys_audit_updated_on
from {{ ref('orders__mwp_orders') }}  o
left join {{ ref('moltres__mwp_store_info') }} i on i.store_id = o.store_id
left join {{ ref('operations_grouping_plans') }} gp on gp.plan = i.plan
left join {{ ref('moltres__mwp_apps') }} apps on concat('app_',apps.id) = o.gateway
left join {{ ref('product__shipping__shipping_carriers__event')}} sc ON o.shipping_method = concat('api_', sc.shipping_carrier_id)
left join ffoo ON o.id = ffoo.order_id and o.store_id = ffoo.store_id
where
TO_DATE(cast(year_month_day_code as string), 'yyyyMMdd') >= DATE_SUB(current_date(), 365)
and completed_at is not null 