-- depends_on: {{ ref('orders__mwp_orders') }}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['fecha','store_id','current_segment_name','country_code','storefront','device_type','gateway_method'],
        on_schema_change='fail',
        partition_by = 'fecha',
        tags=["daily-8am"]
    )
}}

WITH source AS (
    select 
cast(o.started_checkout_at as date) as fecha,
o.store_id,
coalesce(si.current_segment_name, 'No Segment') as current_segment_name,
coalesce(si.country_code, 'No Country') as country_code,
coalesce(o.storefront, 'No Storefront') as storefront,
coalesce(o.device_type, 'No Device type') as device_type,
coalesce(o.gateway_method, 'No Gateway Method') as gateway_method,
count(o.started_checkout_at) as started_checkouts,
count(o.completed_contact_at) as completed_contacts,
count(o.completed_at) as completed_ats,
count(case when o.status <> 'cancelled' and o.payment_status = 'paid' then o.completed_at else null end) as paid_orders
from {{ ref('orders__mwp_orders') }} o
left join {{ ref('company_metrics_merchant_info') }} si on o.store_id = si.store_id
where o.started_checkout_at >= date '2024-01-01'
        {% if is_incremental() %}
            and o.sys_audit_updated_on >= DATE_SUB( (SELECT COALESCE(MAX(fecha), DATE('1900-01-01')) FROM {{ this }}), 45 ) and o.started_checkout_at> DATE('2024-06-01')
        {% endif %}

group by 1,2,3,4,5,6,7
),
    existing_data AS (
        {{ get_existing_data(this, ['fecha','store_id','current_segment_name','country_code','storefront','device_type','gateway_method','started_checkouts',
        'sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
    )
select
    s.fecha,
    s.store_id,
    s.current_segment_name,
    s.country_code,
    s.storefront,
    s.device_type,
    s.gateway_method,
    s.started_checkouts, 
    s.completed_contacts, 
    s.completed_ats, 
    s.paid_orders,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from source s
left join existing_data e on s.fecha = e.fecha and
    s.store_id = e.store_id and
    s.current_segment_name = e.current_segment_name and
    s.country_code = e.country_code and
    s.storefront = e.storefront and
    s.device_type = e.device_type and
    s.gateway_method = e.gateway_method