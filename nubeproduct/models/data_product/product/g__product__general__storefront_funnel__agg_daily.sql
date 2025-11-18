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
select * from  {{ ref('_int_product_general_storefront_checkout_funnel_union') }} 
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
