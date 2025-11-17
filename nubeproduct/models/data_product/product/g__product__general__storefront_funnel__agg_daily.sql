{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['id'],
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}


with base_orders as(
	select distinct
		case when si.country_code in ('AR', 'BR', 'MX', 'CL', 'CO', 'PT', 'US','UY','PA') then si.country_code 
			 else 'other' end as country,
		si.current_segment_name,
	  	si.vertical_name,
    	o.started_checkout_at,
		o.completed_contact_at,
		o.completed_at,
		o.payment_status,
		o.status,
		o.id,
    	p.order_id is not null as has_products,
		mo.option_value as theme, 
		cast(dateadd(hour, -3, o.created_at) as date) date_time,
		CASE WHEN o.storefront like 'store' THEN 'desktop'
		WHEN o.storefront like 'mobile' THEN 'mobile' END as device,
		o.store_id,
		case when tag_online.lightspeed_last_updated_at is not null then 'lightspeed'
  when tag_online.online_metrics_enabled_last_updated_at is not null then 'online-metrics-enabled'
  end as tag
	from data_products_prd.data_staging.orders__mwp_orders o
		left join data_products_prd.data_staging.orders__mwp_order_products p on o.id = p.order_id and p.created_at>= date('2025-01-01')
		left join data_products_prd.data_operations.company_metrics_merchant_info si on si.store_id = o.store_id 
		left join data_products_dev.testing_staging.merchant__attributes__store_online_tags__ref tag_online on o.store_id = tag_online.store_id 
		left join data_products_prd.data_staging.product__general__store_options__event mo on o.store_id = mo.store_id and mo.option_name = 'twig_template'
	where --p.order_id is not null and 
  o.created_at > '2025-08-01'
		and o.storefront in ('store', 'mobile')
    and tag_online.lightspeed_last_updated_at is not null
		)
(select 
	case when sess.visitor_country in ('AR', 'BR', 'MX', 'CL', 'CO', 'PT', 'US','UY','PA') then sess.visitor_country  
		 else 'other' end as country,
	si.current_segment_name,
	si.vertical_name,
  case when tag_online.lightspeed_last_updated_at is not null then 'lightspeed'
  when tag_online.online_metrics_enabled_last_updated_at is not null then 'online-metrics-enabled'
  else null end as tag,
	cast(dateadd(hour, -3, sess.session_timestamp) as date) date,
	case sess.device when 'phone' then 'mobile'
				when 'tablet' then 'mobile'
				when 'computer' then 'desktop' end as device,
	'sessions' as event,
	mo.option_value as theme, 
	case when sess.landing_page LIKE '%checkout/v3%' then 'Checkout' else 'Session' end as checkout_session,
	count(*) count
	from  {{ ref('s__traffic__session__event') }}  sess
	left join {{ ref('company_metrics_merchant_info') }} si on sess.store_id = si.store_id
	left join {{ ref('merchant__attributes__store_online_tags__ref') }} tag_online on sess.store_id = tag_online.store_id 
	left join {{ ref('product__general__store_options__event') }} mo on sess.store_id = mo.store_id and mo.option_name = 'twig_template'
  	where sess.base_date >= '2025-08-01' 
	group by 1,2,3,4,5,6,7,8,9)

UNION ALL
	(	-- Carts
    select 
	country,
	current_segment_name,
	vertical_name,
	tag,
	date_time,
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
	date_time,
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
	date_time,
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
	date_time,
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
	date_time,
	device,
	'paid_orders' as event,
	theme,
	'Not Applicable' as checkout_session,
	count(bo.id) as count
from base_orders bo
inner join data_products_prd.data_operations.company_metrics_paid_orders cmpo on bo.id = cmpo.id
 group by 1,2,3,4,5,6,7,8,9
)