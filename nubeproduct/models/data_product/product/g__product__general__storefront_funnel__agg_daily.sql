{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['country','current_segment_name','vertical_name','tag','date','device','event','theme','checkout_session'],
		partition_by='date',
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}

WITH source AS (
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
		cast(dateadd(hour, -3, o.created_at) as date) date,
		CASE WHEN o.storefront like 'store' THEN 'desktop'
		WHEN o.storefront like 'mobile' THEN 'mobile' END as device,
		o.store_id,
		case when tag_online.lightspeed_last_updated_at is not null then 'lightspeed'
  when tag_online.online_metrics_enabled_last_updated_at is not null then 'online-metrics-enabled'
  end as tag
	from {{ ref('orders__mwp_orders') }} o
		left join {{ ref('orders__mwp_order_products')}} p on o.id = p.order_id and p.created_at>= date('2025-01-01')
		left join {{ ref('company_metrics_merchant_info')}} si on si.store_id = o.store_id 
		left join {{ ref('merchant__attributes__store_online_tags__ref')}} tag_online on o.store_id = tag_online.store_id 
		left join {{ ref('product__general__store_options__event')}} mo on o.store_id = mo.store_id and mo.option_name = 'twig_template'
	where --p.order_id is not null and 
 	 o.created_at > '2025-08-01'
		and o.storefront in ('store', 'mobile')
	{% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    and o.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 day' from {{ this }} )

    {% endif %}

		)
		select * from (
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
		{% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    and sess.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 day' from {{ this }} )

    {% endif %}
	group by 1,2,3,4,5,6,7,8,9)

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
),
existing_data AS (
    {{ get_existing_data(this, ['country','current_segment_name','vertical_name','tag','date','device','event','theme','checkout_session',
		'sys_audit_created_on', 'sys_audit_created_by']) }}
)
select 
s.country,
s.current_segment_name,
s.vertical_name,
s.tag,
s.date,
s.device,
s.event,
s.theme,
s.checkout_session,
s.count,
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM source s
LEFT JOIN existing_data e ON s.country = e.country
	and s.current_segment_name = e.current_segment_name
	and s.vertical_name = e.vertical_name
	and s.tag = e.tag
	and s.date = e.date
	and s.device = e.device
	and s.event = e.event
	and s.theme = e.theme
	and s.checkout_session = e.checkout_session
