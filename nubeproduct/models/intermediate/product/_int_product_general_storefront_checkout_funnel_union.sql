with base_orders as(
	select * from {{ ref('_int_product_general_storefront_funnel_carts') }} o
	{% if is_incremental() %}

    where o.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 day' from {{ ref('g__product__general__storefront_funnel__agg_daily') }}  ) 

    {% endif %}

		)
		select * from (
(select * from {{ ref('_int_product_general_storefront_funnel_sessions') }} sess
		{% if is_incremental() %}

    where sess.date >= (select coalesce(max(date),'1900-01-01') - INTERVAL '1 day' from {{ ref('g__product__general__storefront_funnel__agg_daily') }} )

    {% endif %}
	)

UNION ALL
	(	-- Carts
    select 
	country,
	current_segment_name,
	vertical_name,
	tag,
	date,
	device,
	'carts' as event,
	theme,
	'Not Applicable' as checkout_session,
	count(id) as count
		from base_orders
		where has_products = true
 group by 1,2,3,4,5,6,7,8,9   
)
  UNION ALL

(select
	country,
	current_segment_name,
	vertical_name,
	tag,
	date,
	device,
	'started_checkouts' as event,
	theme,
	'Not Applicable' as checkout_session,
	count(id) as count
from base_orders
		where started_checkout_at is not null
 group by 1,2,3,4,5,6,7,8,9
)

  UNION ALL

(select
	country,
	current_segment_name,
	vertical_name,
	tag,
	date,
	device,
	'completed_contacts' as event,
	theme,
	'Not Applicable' as checkout_session,
	count(id) as count
from base_orders
		where completed_contact_at is not null
 group by 1,2,3,4,5,6,7,8,9
)

  UNION ALL

(select
	country,
	current_segment_name,
	vertical_name,
	tag,
	date,
	device,
	'completed_checkouts' as event,
	theme,
	'Not Applicable' as checkout_session,
	count(id) as count
from base_orders
		where completed_at is not null
 group by 1,2,3,4,5,6,7,8,9
)

  UNION ALL

(select
	bo.country,
	current_segment_name,
	vertical_name,
	tag,
	date,
	device,
	'paid_orders' as event,
	theme,
	'Not Applicable' as checkout_session,
	count(bo.id) as count
from base_orders bo
inner join {{ ref('company_metrics_paid_orders')}} cmpo on bo.id = cmpo.id
 group by 1,2,3,4,5,6,7,8,9
)
) 