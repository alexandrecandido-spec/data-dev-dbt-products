{{
    config(
        materialized='incremental', 
        unique_key=['id'],
        incremental_strategy='merge',
        on_schema_change='fail',
        partition_by=['year_month_day_code', 'flg_gmv'],
        tags=["daily-9am-9pm"],
        cluster_by = ['store_id'],
        post_hook = [
            "OPTIMIZE {{ this }} ZORDER BY (store_id, created_at)"
        ]
    )
}}
-- TODO: arrumar partition_by, pois hoje é em base a completed_at e dever ser com paid_at

WITH existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

select 
    -- order dates
    orders.id,
    orders.order_id,
    orders.store_id,
    orders.country,
    orders.created_at,
    orders.started_checkout_at,
    orders.completed_contact_at,
    orders.completed_at,
    orders.cancelled_at,
    orders.paid_at,
    orders.reporting_month,
    orders.order_traits,
    
    -- orders fields 
    orders.cancel_reason,
    orders.contact_email,
    orders.contact_name,

    --storefront fields
    orders.storefront,  
    orders.device,
    orders.device_type,
    orders.platform_type,

    --payment fields
    orders.status,
    orders.payment_status,
    orders.currency as order_currency,
    CASE
        WHEN orders.country = 'AR' THEN 'ARS'
        WHEN orders.country = 'BR' THEN 'BRL'
        WHEN orders.country = 'MX' THEN 'MXN'
        WHEN orders.country = 'CO' THEN 'COP'
        WHEN orders.country = 'CL' THEN 'CLP'
        ELSE orders.currency
    END AS country_currency,
    CASE
        WHEN orders.country = 'AR' and orders.currency = 'ARS' THEN FALSE
        WHEN orders.country = 'BR' and orders.currency = 'BRL' THEN FALSE
        WHEN orders.country = 'MX' and orders.currency = 'MXN' THEN FALSE
        WHEN orders.country = 'CO' and orders.currency = 'COP' THEN FALSE
        WHEN orders.country = 'CL' and orders.currency = 'CLP' THEN FALSE
        ELSE TRUE
    END AS order_in_foreign_currency,
    orders.product_quantity,
    orders.total_in_usd,
    orders.total_in_local_currency,
    orders.total as total_in_original_currency,
    orders.discount,
    orders.discount_gateway,
    orders.promotional_discount_id,
    orders.payment_handler,
    orders.payment_handler_category,
    orders.gateway,
    orders.internal_extra,
    orders.coupon_id,
    orders.shipping_extra,
    orders.gateway_integration_type,
    orders.gateway_installments,
    orders.gateway_method,
    orders.order_date_store_id,
    orders.app_id,    
    
    --shipping fields
    orders.shipping_method,
    orders.shipping_cost,
    orders.shipping_option,
    orders.shipping_pickup_type,
    orders.shipping_province,
    orders.selected_shipping_partner,
    orders.flg_gsv,
    orders.flg_multicd,
    orders.flg_ne_selected,
    orders.flg_ne_enabled,
    orders.shipping_cost_owner,
    orders.fulfillment_status,
    orders.shipping_handler,
    orders.shipping_handler_category,
    orders.last_payment_at,
    orders.flg_gmv,
    orders.possible_fraud_order,
    orders.is_test_store,

    --session fields
    source_name,
    source_group,
    google_subchannel,
    traffic_type,
    is_end_user,
    visitor_country,

    --audit fields
    year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
    
from {{ ref('_int__orders__orders_enriched_money_flows') }} orders
LEFT JOIN existing_data e ON orders.id = e.id
{% if is_incremental() %}
WHERE
    orders.sys_audit_updated_on > (SELECT MAX(sys_audit_updated_on) FROM {{ this }})
{% endif %}


--consumir somente o que vamos atualizar! 
-- LEFT JOIN (
--   SELECT id, sys_audit_created_on, sys_audit_created_by
--   FROM {{ this }}
--   WHERE year_month_day_code >= (SELECT MAX(year_month_day_code) - 1 FROM {{ this }})
-- ) e
-- ON source.id = e.id