-- depends_on: {{ ref('s__traffic__cart_checkout_funnel__event') }}
-- depends_on: {{ ref('s__traffic__cart_checkout_funnel__event') }}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=["daily-1am"]
    )
}}

select 
ccfe.base_date,
case when wbr.store_id is not null then ccfe.store_id
    when (cmmi.current_segment_name is null or cmmi.current_segment_name in ('Not Informed', 'struggling-seller', 
    'no-seller', 'tiny-seller', 'small-seller', 'medium-seller')) and wbr.store_id is null then 'No Seller'
    when (not(cmmi.current_segment_name is null or cmmi.current_segment_name in ('Not Informed', 'struggling-seller', 
    'no-seller', 'tiny-seller', 'small-seller', 'medium-seller'))) or wbr.store_id is not null then ccfe.store_id
else 'Otro caso' end as store_id,
ccfe.checkout_start_timestamp is not null as checkout_start_timestamp,
ccfe.checkout_filled_email_timestamp is not null as checkout_filled_email_timestamp,
--ccfe.checkout_filled_shipping_zipcode_timestamp is not null as checkout_filled_shipping_zipcode_timestamp,
--ccfe.checkout_selected_shipping_method_timestamp is not null as checkout_selected_shipping_method_timestamp,
--ccfe.checkout_filled_shipping_first_name_timestamp is not null as checkout_filled_shipping_first_name_timestamp,
--ccfe.checkout_filled_shipping_last_name_timestamp is not null as checkout_filled_shipping_last_name_timestamp,
--ccfe.checkout_filled_shipping_phone_timestamp is not null as checkout_filled_shipping_phone_timestamp,
--ccfe.checkout_clicked_shipping_continue_timestamp is not null as checkout_clicked_shipping_continue_timestamp,
ccfe.checkout_clicked_shipping_continue_to_payment_timestamp is not null as checkout_clicked_shipping_continue_to_payment_timestamp,
--ccfe.checkout_filled_billing_id_number_timestamp is not null as checkout_filled_billing_id_number_timestamp,
--ccfe.checkout_checked_billing_same_address_timestamp is not null as checkout_checked_billing_same_address_timestamp,
--ccfe.checkout_filled_billing_country_timestamp is not null as checkout_filled_billing_country_timestamp,
--ccfe.checkout_filled_billing_business_name_timestamp is not null as checkout_filled_billing_business_name_timestamp,
--ccfe.checkout_filled_billing_trade_name_timestamp is not null as checkout_filled_billing_trade_name_timestamp,
--ccfe.checkout_filled_billing_state_registration_timestamp is not null as checkout_filled_billing_state_registration_timestamp,
--ccfe.checkout_filled_billing_business_activity_timestamp is not null as checkout_filled_billing_business_activity_timestamp,
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
where base_date> DATE('2025-08-01')
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32--,33,34,35,36,37,38,39,40,41