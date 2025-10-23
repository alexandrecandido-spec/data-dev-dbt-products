--sin ffoo
(select
    o.store_id, 
    s.domain,
    o.id as order_id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'sin fulfillment order' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on,
        fo.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
left join {{ref('product__orders__fulfillment_orders__event')}} fo on o.id = fo.order_id
where 
    o.completed_at is not null 
    and o.id is not NULL
    and o.year_month_day_code>=20250101
    and fo.id is null 
)
union
--con sobreventa
(select
    o.store_id, 
    s.domain,
    o.id as order_id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'sobreventa' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
    storefront in ('mobile','store')
    and o.completed_at is not null
    and o.id is not NULL
    and o.gateway_integration_type is null
    and o.internal_extra LIKE '%stock_issue%'
    and o.year_month_day_code>=20250101
)
union
--con gateway_integration_type nulo
(select
    o.store_id, 
    s.domain,
    o.id as order_id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at,
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'gateway_integration_type null' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
    storefront in ('mobile','store')
    and o.completed_at is not null
    and o.id is not NULL
    and o.gateway_integration_type is null
    and o.year_month_day_code>=20250101
)
union
--completed at nulo
(select 
    o.store_id, 
    s.domain,
    o.id as order_id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'completed_at nulo' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where  
    o.completed_at is null 
    and o.id is not NULL
    and o.year_month_day_code>=20250101
)
union
--order id null
(select 
    o.store_id, 
    s.domain,
    o.id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'order_id nulo' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
    o.completed_at is not null 
    AND o.id is null
    and o.year_month_day_code>=20250101
    and ( o.storefront <> 'form'and o.status <> 'cancelled')
)
union(
--no line items
select 
    o.store_id, 
    s.domain,
    o.id as order_id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'Sin lineitems' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
	o.completed_at is not null
  	and o.year_month_day_code>=20250101
    AND o.id is not null
  	and o.id not in (select DISTINCT (order_id) from {{ref('orders__mwp_order_products')}})
)
union(
--sin contact name
select 
    o.store_id, 
    s.domain,
    o.id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'Sin contact_name' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
    o.completed_at is not null
    and o.id is not null
    and o.year_month_day_code>=20250101
    and (o.contact_name is null or lower(o.contact_name) like '%undefined%')
)
union(
--completed_at<<created_at
select 
    o.store_id, 
    s.domain,
    o.id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'completed_at errado' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
    o.completed_at is not null 
    and o.id is not null
    and o.year_month_day_code>=20250101
    and o.completed_at<o.created_at
)
union(
--sin gateway data
select 
    o.store_id, 
    s.domain,
    o.id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'Sin datos de gateway' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
    o.completed_at is not null
    and o.gateway is null
    and o.id is not null
    and o.year_month_day_code>=20250101
    and o.status <> 'cancelled'
)
union(
--no contact email
select 
    o.store_id, 
    s.domain,
    o.id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'Sin contact_email' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
    o.completed_at is not null
    and o.id is not null
    and o.year_month_day_code>=20250101
    and ( o.contact_email is null 
    or lower(o.contact_email) in ('no informado', 'não informado' , 'not-provided')) 
)
union(
--sin shipping cost
select 
    o.store_id, 
    s.domain,
    o.id,
    o.contact_email,
    cast(o.created_at as date) as created_at,
    cast(o.completed_at as date) as completed_at, 
    o.payment_status ,
    o.status as order_status,
    o.storefront,
    s.country,
    s.current_segment,
    'carrier pickup sin shipping_cost' as issue_type,
    greatest(
        o.sys_audit_updated_on,
        s.sys_audit_updated_on
    ) as max_sys_audit_updated_on
from {{ref('moltres__mwp_store_info')}} s
left join {{ref('orders__mwp_orders')}} o on s.store_id = o.store_id
where 
    o.completed_at is not null
    and o.id is not null
    and o.year_month_day_code>=20250101
    and o.shipping_pickup_type='pickup'
    and o.shipping_method like 'api_%'
    and o.shipping_cost is null
)