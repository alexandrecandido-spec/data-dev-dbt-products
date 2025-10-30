-- depends_on: {{ ref('s__traffic__cart_checkout_funnel__event') }}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['base_date','store_id','checkout_start_timestamp','checkout_filled_email_timestamp','checkout_clicked_shipping_continue_to_payment_timestamp','checkout_selected_payment_method_timestamp',
        'checkout_clicked_payment_complete_order_timestamp','checkout_order_placed_timestamp','checkout_order_paid_timestamp','started_checkout','completed_contact','completed_at','wallet','payment_method_name','payment_method_type','payment_method_integration_type',
    'shipping_method_type','shipping_method_id','shipping_method_code','payment_retry_feature','theme','country_code','current_segment_name','group_name','mid_market','vertical_name','payment_status','gateway','gateway_method','gateway_integration_type','storefront','device_type','FTP'],
        on_schema_change='fail',
        partition_by = 'base_date',
        tags=["daily-1am"]
    )
}}
WITH source AS (
select 
ccfe.base_date,
case when wbr.store_id is not null then ccfe.store_id
    when (cmmi.current_segment_name is null or cmmi.current_segment_name in ('Not Informed', 'struggling-seller', 
    'no-seller', 'tiny-seller', 'small-seller', 'medium-seller')) and wbr.store_id is null then 'Medium or smaller'
    when (not(cmmi.current_segment_name is null or cmmi.current_segment_name in ('Not Informed', 'struggling-seller', 
    'no-seller', 'tiny-seller', 'small-seller', 'medium-seller'))) or wbr.store_id is not null then ccfe.store_id
else 'Otro caso' end as store_id,
ccfe.checkout_start_timestamp is not null as checkout_start_timestamp,
ccfe.checkout_filled_email_timestamp is not null as checkout_filled_email_timestamp,
ccfe.checkout_clicked_shipping_continue_to_payment_timestamp is not null as checkout_clicked_shipping_continue_to_payment_timestamp,
ccfe.checkout_selected_payment_method_timestamp is not null as checkout_selected_payment_method_timestamp,
ccfe.checkout_clicked_payment_complete_order_timestamp is not null as checkout_clicked_payment_complete_order_timestamp,
ccfe.checkout_order_placed_timestamp is not null as checkout_order_placed_timestamp,
ccfe.checkout_order_paid_timestamp is not null as checkout_order_paid_timestamp,
mo.started_checkout_at is not null as started_checkout,
mo.completed_contact_at is not null as completed_contact,
mo.completed_at is not null as completed_at,
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
case when si.custom_theme is not null then 'Open FTP' else 'Closed FTP' end as FTP,
count(distinct ccfe.cart_id) as q_carts,
sum(mo.total) as total,
sum(mo.total_in_usd) as total_in_usd
FROM {{ ref('s__traffic__cart_checkout_funnel__event') }} ccfe
left join {{ ref('company_metrics_merchant_info') }} cmmi on ccfe.store_id = cmmi.store_id
left join {{ ref('product__mwp_options') }} mop on ccfe.store_id = mop.store_id and mop.option_name = 'twig_template'
left join {{ ref('orders__mwp_orders') }} mo on ccfe.cart_id = mo.id and mo.created_at>=date('2025-01-01')
left join {{ ref('merchant__attributes__store_info__ref') }} si on ccfe.store_id = si.store_id
left join {{ ref('midmarket_weekly_business_review') }}  wbr on ccfe.store_id = wbr.store_id and ccfe.base_date between wbr.date_from and wbr.date_to
    and playbook not in ('Out of portfolio', 'Effective churn')
WHERE
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    base_date >= DATE_SUB( (SELECT COALESCE(MAX(base_date), DATE('1900-01-01')) FROM {{ this }}), 60 )

    {% else %}

    base_date> DATE('2025-01-01')

     {% endif %}
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33

),
existing_data AS (
    {{ get_existing_data(this, ['base_date','store_id','checkout_start_timestamp','checkout_filled_email_timestamp','checkout_clicked_shipping_continue_to_payment_timestamp','checkout_selected_payment_method_timestamp',
    'checkout_clicked_payment_complete_order_timestamp','checkout_order_placed_timestamp','checkout_order_paid_timestamp','started_checkout','completed_contact','completed_at','wallet','payment_method_name','payment_method_type','payment_method_integration_type',
    'shipping_method_type','shipping_method_id','shipping_method_code','payment_retry_feature','theme','country_code','current_segment_name','group_name','mid_market','vertical_name','payment_status','gateway','gateway_method','gateway_integration_type','storefront','device_type','FTP','q_carts',
    'total', 'total_in_usd', 'sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
)
SELECT 
s.base_date,
s.store_id,
s.checkout_start_timestamp,
s.checkout_filled_email_timestamp,
s.checkout_clicked_shipping_continue_to_payment_timestamp,
s.checkout_selected_payment_method_timestamp,
s.checkout_clicked_payment_complete_order_timestamp,
s.checkout_order_placed_timestamp,
s.checkout_order_paid_timestamp,
s.started_checkout,
s.completed_contact,
s.completed_at,
s.wallet,
s.payment_method_name,
s.payment_method_type,
s.payment_method_integration_type,
s.shipping_method_type,
s.shipping_method_id,
s.shipping_method_code,
s.payment_retry_feature,
s.theme,
s.country_code,
s.current_segment_name,
s.group_name,
s.mid_market,
s.vertical_name,
s.payment_status,
s.gateway,
s.gateway_method,
s.gateway_integration_type,
s.storefront,
s.device_type,
s.FTP,
s.q_carts,
s.total,
s.total_in_usd,
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
from source s
left join existing_data e on
    s.base_date = e.base_date AND 
    s.store_id = e.store_id AND 
    s.checkout_start_timestamp = e.checkout_start_timestamp AND 
    s.checkout_filled_email_timestamp = e.checkout_filled_email_timestamp AND 
    s.checkout_clicked_shipping_continue_to_payment_timestamp = e.checkout_clicked_shipping_continue_to_payment_timestamp AND 
    s.checkout_selected_payment_method_timestamp = e.checkout_selected_payment_method_timestamp AND 
    s.checkout_clicked_payment_complete_order_timestamp = e.checkout_clicked_payment_complete_order_timestamp AND 
    s.checkout_order_placed_timestamp = e.checkout_order_placed_timestamp AND 
    s.checkout_order_paid_timestamp = e.checkout_order_paid_timestamp AND 
    s.started_checkout = e.started_checkout AND 
    s.completed_contact = e.completed_contact AND 
    s.completed_at = e.completed_at AND 
    s.wallet = e.wallet AND 
    s.payment_method_name = e.payment_method_name AND 
    s.payment_method_type = e.payment_method_type AND 
    s.payment_method_integration_type = e.payment_method_integration_type AND 
    s.shipping_method_type = e.shipping_method_type AND 
    s.shipping_method_id = e.shipping_method_id AND 
    s.shipping_method_code = e.shipping_method_code AND 
    s.payment_retry_feature = e.payment_retry_feature AND 
    s.theme = e.theme AND 
    s.country_code = e.country_code AND 
    s.current_segment_name = e.current_segment_name AND 
    s.group_name = e.group_name AND 
    s.mid_market = e.mid_market AND 
    s.vertical_name = e.vertical_name AND 
    s.payment_status = e.payment_status AND 
    s.gateway = e.gateway AND 
    s.gateway_method = e.gateway_method AND 
    s.gateway_integration_type = e.gateway_integration_type AND 
    s.storefront = e.storefront AND 
    s.device_type = e.device_type AND 
    s.FTP = e.FTP