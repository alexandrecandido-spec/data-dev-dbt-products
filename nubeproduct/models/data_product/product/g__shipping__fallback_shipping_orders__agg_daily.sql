{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id', 'order_completed_at', 'shipping_method'],
        on_schema_change='fail',
        partition_by=['year_month_day_code'],
        tags=['daily-9am']
    )
}}

-- g__shipping__fallback_shipping_orders__agg_daily

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'order_completed_at', 'shipping_method', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

base AS (
    
    SELECT
        o.store_id,
        fss.domain,
        fss.country,
        fss.plan_group,
        fss.segment,
        fss.state,
        fss.is_churned,
        fss.is_fallback_active,
        fss.is_freemium,
        o.shipping_method,
        CASE
            WHEN o.shipping_method = 'Fallback' THEN TRUE
            ELSE FALSE
        END AS is_fallback_order,
        DATE(o.order_completed_at) AS order_completed_at,
        o.year_month_day_code,
        SUM(o.total) as total_local_currency,
        SUM(o.total_in_usd) as total_usd,
        COUNT(DISTINCT o.order_id) as total_orders


FROM {{ ref('s__orders__orders_last_12_months__event') }} o

JOIN {{ ref('s__shipping__fallback_shipping_status__ref') }} fss
    ON o.store_id = fss.store_id


WHERE 1=1
    AND o.order_completed_at IS NOT NULL
    AND o.payment_status = 'paid'
    AND o.status <> 'cancelled'
    AND o.storefront NOT IN ('form', 'pos')


{% if is_incremental() %}
AND GREATEST(
    COALESCE(fss.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP)),
    COALESCE(o.sys_audit_updated_on, CAST('1900-01-01' AS TIMESTAMP))
) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), CAST('1900-01-01' AS TIMESTAMP)) FROM {{ this }}
)
{% endif %}

GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13

)


SELECT
    b.*,

    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by


FROM base b

LEFT JOIN existing_data e
    ON e.store_id = b.store_id
    AND e.order_completed_at = b.order_completed_at
    AND e.shipping_method = b.shipping_method