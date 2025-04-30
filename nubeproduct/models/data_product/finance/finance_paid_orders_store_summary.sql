{{
    config(
        materialized='incremental',
        unique_key=['id'],
        incremental_strategy='merge',
        on_schema_change='fail',
        partition_by='year_month_day_code',
        tags=["daily-morning"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    orders.id,
    orders.store_id,
    orders.country,
    orders.completed_at,
    orders.gateway,
    orders.shipping_method,
    orders.storefront,
    orders.currency,
    CASE
        WHEN orders.country = 'AR' THEN 'ARS'
        WHEN orders.country = 'BR' THEN 'BRL'
        WHEN orders.country = 'MX' THEN 'MXN'
        WHEN orders.country = 'CO' THEN 'COP'
        WHEN orders.country = 'CL' THEN 'CLP'
        ELSE orders.currency
    END AS country_currency,
    orders.total,
    orders.shipping_cost,
    orders.total_in_usd,
    orders.total_in_usd_billing,
    orders.total_in_local_currency,
    orders.gateway_integration_type,
    orders.shipping_option,
    orders.shipping_pickup_type,
    orders.shipping_province,
    orders.gateway_installments,
    orders.contact_email,
    orders.paid_at,
    orders.store_status,
    orders.payment,
    orders.shipping,
    orders.platform_type,
    orders.year_month_day_code,
    CASE
        WHEN orders.country = 'AR' and orders.currency = 'ARS' THEN FALSE
        WHEN orders.country = 'BR' and orders.currency = 'BRL' THEN FALSE
        WHEN orders.country = 'MX' and orders.currency = 'MXN' THEN FALSE
        WHEN orders.country = 'CO' and orders.currency = 'COP' THEN FALSE
        WHEN orders.country = 'CL' and orders.currency = 'CLP' THEN FALSE
        ELSE TRUE
    END AS is_foreign_currency,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_finance_paid_orders_store_summary__get_store_info') }} orders
LEFT JOIN existing_data e ON orders.id = e.id
{% if is_incremental() %}
WHERE 
    orders.completed_at
    >= (SELECT MAX(DATE(sys_audit_updated_on)) FROM {{ this }})
    OR orders.cancelled_at
    >= (SELECT MAX(DATE(sys_audit_updated_on)) FROM {{ this }})
{% endif %}