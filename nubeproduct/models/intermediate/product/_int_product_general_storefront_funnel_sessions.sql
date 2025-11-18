select 
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
    group by 1,2,3,4,5,6,7,8,9