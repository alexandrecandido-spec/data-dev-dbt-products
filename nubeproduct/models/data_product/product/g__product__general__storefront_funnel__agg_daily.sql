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
	select * from {{ ref('_int_product_general_storefront_funnel_carts') }} o
	{% if is_incremental() %}

    where o.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 day' from {{ this }} )

    {% endif %}

		)
		select * from (
(select * from {{ ref('_int_product_general_storefront_funnel_sessions') }} sess
		{% if is_incremental() %}

    where sess.date >= (select coalesce(max(date),'1900-01-01') - INTERVAL '1 day' from {{ this }} )

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
