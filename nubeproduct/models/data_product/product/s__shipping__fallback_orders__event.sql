{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['order_id'],
        on_schema_change='fail',
        partition_by=['year_month_day_code'],
        tags=['daily-9am']
    )
}}

-- s__shipping__fallback_orders__event

WITH existing_data AS (
    {{ get_existing_data(this, ['order_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

base AS (
    
    SELECT
        o.store_id,
        fs.domain,
        fs.country,
        fs.plan_group,
        fs.segment,
        fs.state,
        fs.is_churned,
        fs.is_fallback_active,
        fs.is_freemium,
        o.order_id,
        COALESCE(o.shipping_method, 'Without shipping data') as shipping_method,
        CASE
            WHEN o.shipping_method = 'Fallback' THEN TRUE
            ELSE FALSE
        END AS is_fallback_order,
        DATE(o.order_completed_at) AS order_completed_at,
        CAST(date_format(o.order_completed_at, 'yyyyMMdd') AS INTEGER) AS year_month_day_code,
        SUM(o.total) as total_local_currency,
        SUM(o.total_in_usd) as total_usd


FROM {{ ref('s__orders__orders_last_12_months__event') }} o

JOIN {{ ref('s__shipping__fallback_status__ref') }} fs
    ON o.store_id = fs.store_id


WHERE 1=1
    AND o.order_completed_at IS NOT NULL
    AND o.payment_status = 'paid'
    AND o.status <> 'cancelled'
    AND o.storefront NOT IN ('form', 'pos')
    AND o.shipping_method = 'Fallback'


{% if is_incremental() %}
AND GREATEST(
    COALESCE(fs.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
    COALESCE(o.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), CAST('1900-01-01' AS TIMESTAMP)) FROM {{ this }}
)
{% endif %}

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14

)


SELECT
    b.*,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by


FROM base b

LEFT JOIN existing_data e
    ON e.order_id = b.order_id