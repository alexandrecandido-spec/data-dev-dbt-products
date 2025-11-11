
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['cart_id'],
        on_schema_change='fail',
        partition_by = 'fecha',
        tags=["daily-8am"]
    )
}}
WITH source AS (
    select 
	cast(o.started_checkout_at as date) as fecha,
	o.id as cart_id,
	o.store_id,
	si.current_segment_name,
	si.country_code,
	o.storefront,
	o.device_type,
	o.gateway_method,
	o.started_checkout_at,
	o.completed_contact_At,
	o.completed_at,
	DATEDIFF(second,o.started_checkout_at,o.completed_at) as total_checkout_time,
	DATEDIFF(second,o.completed_contact_At,o.completed_at) as completed_contact_to_completed_at,
	DATEDIFF(second,o.started_checkout_at,o.completed_contact_At) as started_checkout_to_completed_contact
	from {{ ref('orders__mwp_orders') }} o  
	left join {{ ref('company_metrics_merchant_info') }} si on o.store_id = si.store_id
	where o.completed_contact_at is not null
    and
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    o.started_checkout_at >= DATE_SUB( (SELECT COALESCE(MAX(fecha), DATE('1900-01-01')) FROM {{ this }}), 60 )

    {% else %}

    o.started_checkout_at> DATE('2025-01-01')

     {% endif %}
)
,
existing_data AS (
    {{ get_existing_data(this, ['fecha','cart_id','store_id','current_segment_name','country_code','storefront','device_type','gateway_method','started_checkout_at',
    'completed_contact_At','completed_at','total_checkout_time','completed_contact_to_completed_at','started_checkout_to_completed_contact', 
    'sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
)
select 
coalesce(s.fecha, e.fecha) as fecha,
coalesce(s.cart_id, e.cart_id) as cart_id,
coalesce(s.store_id, e.store_id) as store_id,
coalesce(s.current_segment_name, e.current_segment_name) as current_segment_name,
coalesce(s.country_code, e.country_code) as country_code,
coalesce(s.storefront, e.storefront) as storefront,
coalesce(s.device_type, e.device_type) as device_type,
coalesce(s.gateway_method, e.gateway_method) as gateway_method,
coalesce(s.started_checkout_at, e.started_checkout_at) as started_checkout_at,
coalesce(s.completed_contact_At, e.completed_contact_At) as completed_contact_At,
coalesce(s.completed_at, e.completed_at) as completed_at,
coalesce(s.total_checkout_time, e.total_checkout_time) as total_checkout_time,
coalesce(s.completed_contact_to_completed_at, e.completed_contact_to_completed_at) as completed_contact_to_completed_at,
coalesce(s.started_checkout_to_completed_contact, e.started_checkout_to_completed_contact) as started_checkout_to_completed_contact,
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
from source s
left join existing_data e on s.cart_id = e.cart_id