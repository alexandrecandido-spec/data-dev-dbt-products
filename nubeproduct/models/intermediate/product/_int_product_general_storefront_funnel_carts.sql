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
		cast(dateadd(hour, -3, o.created_at) as date) date,
		CASE WHEN o.storefront like 'store' THEN 'desktop'
		WHEN o.storefront like 'mobile' THEN 'mobile' END as device,
		o.store_id,
		case when tag_online.lightspeed_last_updated_at is not null then 'lightspeed'
  when tag_online.online_metrics_enabled_last_updated_at is not null then 'online-metrics-enabled'
  end as tag,
  o.sys_audit_updated_on
	from {{ ref('orders__mwp_orders') }} o
		left join {{ ref('orders__mwp_order_products')}} p on o.id = p.order_id and p.created_at>= date('2025-01-01')
		left join {{ ref('company_metrics_merchant_info')}} si on si.store_id = o.store_id 
		left join {{ ref('merchant__attributes__store_online_tags__ref')}} tag_online on o.store_id = tag_online.store_id 
		left join {{ ref('product__general__store_options__event')}} mo on o.store_id = mo.store_id and mo.option_name = 'twig_template'
	where --p.order_id is not null and 
 	 o.created_at > '2025-08-01'
     and o.storefront in ('store', 'mobile')