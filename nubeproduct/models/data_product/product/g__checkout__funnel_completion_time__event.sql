-- depends_on: {{ ref('s__traffic__cart_checkout_funnel__event') }}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['cart_id'],
        on_schema_change='fail',
        partition_by = 'base_date',
        tags=["daily-1am"]
    )
}}
WITH source AS (
select 
ccfe.base_date,
ccfe.cart_id,
ccfe.store_id,
DATEDIFF(MINUTE, ccfe.first_event_timestamp, ccfe.last_event_timestamp) as diff_first_and_last_event_minutes,
DATEDIFF(SECOND, ccfe.checkout_selected_payment_method_timestamp, paid_timestamp.paid_order_timestamp) as diff_selected_payment_to_paid_seconds,
DATEDIFF(SECOND, ccfe.checkout_clicked_shipping_continue_to_payment_timestamp, ccfe.checkout_selected_payment_method_timestamp) as diff_completed_contact_to_selected_payment_seconds,
ccfe.first_event,
ccfe.first_event_timestamp,
ccfe.last_event,
ccfe.last_event_timestamp,
ccfe.checkout_selected_payment_method_timestamp,
paid_timestamp.paid_order_timestamp,
ccfe.checkout_clicked_shipping_continue_to_payment_timestamp,
ccfe.wallet,
ccfe.payment_method_name,
ccfe.payment_method_type,
ccfe.payment_method_integration_type,
ccfe.shipping_method_type,
ccfe.shipping_method_id,
ccfe.shipping_method_code,
ccfe.payment_retry_feature,
mop.option_value as theme,
cmmi.country_code,
cmmi.current_segment_name,
cmmi.group_name,
wbr.store_id is not null as mid_market,
cmmi.vertical_name,
mo.payment_status,
mo.gateway,
mo.gateway_method,
mo.gateway_integration_type,
mo.storefront,
mo.device_type,
case when si.custom_theme is not null then 'Open FTP' else 'Closed FTP' end as FTP
FROM {{ ref('s__traffic__cart_checkout_funnel__event') }} ccfe
left join {{ ref('company_metrics_merchant_info') }} cmmi on ccfe.store_id = cmmi.store_id
left join {{ ref('product__general__store_options__event') }} mop on ccfe.store_id = mop.store_id and mop.option_name = 'twig_template'
left join {{ ref('orders__mwp_orders') }} mo on ccfe.cart_id = mo.id and mo.created_at>=date('2025-01-01')
left join {{ ref('merchant__attributes__store_info__ref') }} si on ccfe.store_id = si.store_id
left join {{ ref('midmarket_weekly_business_review') }}  wbr on ccfe.store_id = wbr.store_id 
    and ccfe.base_date >= wbr.date_from and ccfe.base_date < wbr.date_to
    and playbook not in ('Out of portfolio', 'Effective churn')
left join {{ ref('_int__product__orders__paid_event_timestamp') }} paid_timestamp on ccfe.cart_id = paid_timestamp.order_id
WHERE
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    base_date >= DATE_SUB( (SELECT COALESCE(MAX(base_date), DATE('1900-01-01')) FROM {{ this }}), 60 )

    {% else %}

    base_date> DATE('2025-01-01')

     {% endif %}

),
existing_data AS (
    {{ get_existing_data(this, ['base_date','cart_id','store_id','diff_first_and_last_event_minutes','diff_selected_payment_to_paid_seconds','diff_completed_contact_to_selected_payment_seconds','first_event','first_event_timestamp',
'last_event','last_event_timestamp','checkout_selected_payment_method_timestamp','paid_order_timestamp','checkout_clicked_shipping_continue_to_payment_timestamp','wallet','payment_method_name','payment_method_type',
'payment_method_integration_type','shipping_method_type','shipping_method_id','shipping_method_code','payment_retry_feature','theme','country_code','current_segment_name','group_name',
'mid_market','vertical_name','payment_status','gateway','gateway_method','gateway_integration_type','storefront','device_type','FTP','sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
)

select
coalesce(s.base_date, e.base_date) as base_date,
coalesce(s.cart_id, e.cart_id) as cart_id,
coalesce(s.store_id, e.store_id) as store_id,
coalesce(s.diff_first_and_last_event_minutes, e.diff_first_and_last_event_minutes) as diff_first_and_last_event_minutes,
coalesce(s.diff_selected_payment_to_paid_seconds, e.diff_selected_payment_to_paid_seconds) as diff_selected_payment_to_paid_seconds,
coalesce(s.diff_completed_contact_to_selected_payment_seconds, e.diff_completed_contact_to_selected_payment_seconds) as diff_completed_contact_to_selected_payment_seconds,
coalesce(s.first_event, e.first_event) as first_event,
coalesce(s.first_event_timestamp, e.first_event_timestamp) as first_event_timestamp,
coalesce(s.last_event, e.last_event) as last_event,
coalesce(s.last_event_timestamp, e.last_event_timestamp) as last_event_timestamp,
coalesce(s.checkout_selected_payment_method_timestamp, e.checkout_selected_payment_method_timestamp) as checkout_selected_payment_method_timestamp,
coalesce(s.paid_order_timestamp, e.paid_order_timestamp) as paid_order_timestamp,
coalesce(s.checkout_clicked_shipping_continue_to_payment_timestamp, e.checkout_clicked_shipping_continue_to_payment_timestamp) as checkout_clicked_shipping_continue_to_payment_timestamp,
coalesce(s.wallet, e.wallet) as wallet,
coalesce(s.payment_method_name, e.payment_method_name) as payment_method_name,
coalesce(s.payment_method_type, e.payment_method_type) as payment_method_type,
coalesce(s.payment_method_integration_type, e.payment_method_integration_type) as payment_method_integration_type,
coalesce(s.shipping_method_type, e.shipping_method_type) as shipping_method_type,
coalesce(s.shipping_method_id, e.shipping_method_id) as shipping_method_id,
coalesce(s.shipping_method_code, e.shipping_method_code) as shipping_method_code,
coalesce(s.payment_retry_feature, e.payment_retry_feature) as payment_retry_feature,
coalesce(s.theme, e.theme) as theme,
coalesce(s.country_code, e.country_code) as country_code,
coalesce(s.current_segment_name, e.current_segment_name) as current_segment_name,
coalesce(s.group_name, e.group_name) as group_name,
coalesce(s.mid_market, e.mid_market) as mid_market,
coalesce(s.vertical_name, e.vertical_name) as vertical_name,
coalesce(s.payment_status, e.payment_status) as payment_status,
coalesce(s.gateway, e.gateway) as gateway,
coalesce(s.gateway_method, e.gateway_method) as gateway_method,
coalesce(s.gateway_integration_type, e.gateway_integration_type) as gateway_integration_type,
coalesce(s.storefront, e.storefront) as storefront,
coalesce(s.device_type, e.device_type) as device_type,
coalesce(s.FTP, e.FTP) as FTP,
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
from source s
left join existing_data e on s.base_date = e.base_date and s.cart_id = e.cart_id