{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['order_id', 'shipping_carrier_app_id'],
        on_schema_change='fail',
        partition_by=['year_month_day_code'],
        tags=['daily-9am']
    )
}}

-- s__shipping__fallback_carrier_status__event

WITH existing_data AS (
    {{ get_existing_data(this, ['order_id', 'shipping_carrier_app_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

int_data AS (    
    SELECT * FROM {{ ref('_int__product__shipping__fallback_carrier_status_input') }}
)


SELECT
    i.store_id,
    i.domain,
    i.country,
    i.plan_group,
    i.segment,
    i.state,
    i.is_churned,
    i.is_fallback_active,
    i.is_freemium,
    i.order_id,
    i.shipping_carrier_name,
    i.shipping_carrier_app_id,
    i.was_carrier_active_when_fallback,
    i.shipping_method,
    i.is_fallback_order,
    i.order_completed_at,
    i.year_month_day_code,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM int_data i

LEFT JOIN existing_data e
    ON e.order_id = i.order_id
    AND e.shipping_carrier_app_id = i.shipping_carrier_app_id

WHERE 1=1

{% if is_incremental() %}

AND i.sys_audit_updated_on >= (SELECT COALESCE(MAX(sys_audit_updated_on), CAST('1900-01-01' AS TIMESTAMP)) FROM {{ this }})

{% endif %}