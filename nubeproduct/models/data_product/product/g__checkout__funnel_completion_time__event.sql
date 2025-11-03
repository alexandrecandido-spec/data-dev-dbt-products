-- depends_on: {{ ref('s__traffic__cart_checkout_funnel__event') }}
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['base_date','cart_id'],
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
left join {{ ref('midmarket_weekly_business_review') }}  wbr on ccfe.store_id = wbr.store_id and ccfe.base_date between wbr.date_from and wbr.date_to
    and playbook not in ('Out of portfolio', 'Effective churn')
left join {{ ref('_int__product__orders__paid_event_timestamp') }} paid_timestamp on ccfe.cart_id = paid_timestamp.order_id
WHERE
    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    base_date >= DATE_SUB( (SELECT COALESCE(MAX(base_date), DATE('1900-01-01')) FROM {{ this }}), 30 )

    {% else %}

    base_date> DATE('2025-01-01')

     {% endif %}

),
existing_data AS (
    {{ get_existing_data(this, ['base_date','cart_id','sys_audit_created_on', 'sys_audit_created_by', 'sys_audit_updated_on', 'sys_audit_updated_by']) }}
)

select
s.base_date,
s.cart_id,
s.store_id,
s.diff_first_and_last_event_minutes,
s.diff_selected_payment_to_paid_seconds,
s.diff_completed_contact_to_selected_payment_seconds,
s.first_event,
s.first_event_timestamp,
s.last_event,
s.last_event_timestamp,
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
COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
from source s
left join existing_data e on s.base_date = e.base_date and s.cart_id = e.cart_id