{{ config(
    materialized        = "incremental",
    incremental_strategy= "merge",
    partition_by        = "year_month_day_code",
    unique_key          = "row_key",
    on_schema_change    = "fail",
    tags                = ["daily-9am-9pm"]
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['row_key', 'orders', 'gmv', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

base_data AS (
    SELECT
        o.country,
        o.vertical,
        o.province,
        o.city,
        o.region,
        o.business_size,
        o.segment,
        o.nice_9_name,
        o.plan_group,
        o.bu,
        o.date,
        o.year_month_day_code,
        o.mes,
        o.platform_type,
        o.storefront,
        o.device,
        o.payment_provider,
        o.payment_method,
        o.shipping_method,
        o.shipping_province,
        o.gateway_installments,
        o.order_source,
        o.social_network,
        o.source_details,
        o.source_type,
        o.gmv,
        o.gmv_usd,
        o.orders,
        o.orders_free_shipping,
        o.products,
        o.stores,
        lower(hex(md5(concat_ws(
            '|',
            cast(o.country as varchar(10)),
            coalesce(o.vertical, ''),
            coalesce(o.province, ''),
            coalesce(o.city, ''),
            coalesce(o.region, ''),
            coalesce(o.business_size, ''),
            coalesce(o.segment, ''),
            coalesce(o.nice_9_name, ''),
            coalesce(o.plan_group, ''),
            coalesce(o.bu, ''),
            cast(o.date as varchar(10)),
            cast(o.year_month_day_code as varchar(10)),
            cast(o.mes as varchar(10)),
            coalesce(o.platform_type, ''),
            coalesce(o.storefront, ''),
            coalesce(o.device, ''),
            coalesce(o.payment_provider, ''),
            coalesce(o.payment_method, ''),
            coalesce(o.shipping_method, ''),
            coalesce(o.shipping_province, ''),
            cast(o.gateway_installments as varchar(10)),
            coalesce(o.order_source, ''),
            coalesce(o.social_network, ''),
            coalesce(o.source_details, ''),
            cast(o.orders_free_shipping as varchar(10)),
            coalesce(o.source_type, '')
        )))) AS row_key
    FROM {{ ref('_int__operations__orders_gmv__agg_daily_prep') }} o
)

SELECT
    b.*,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM base_data b
LEFT JOIN existing_data e ON b.row_key = e.row_key
WHERE
    {% if is_incremental() %}
        e.row_key IS NULL
        OR b.orders IS DISTINCT FROM e.orders
        OR b.gmv IS DISTINCT FROM e.gmv
    {% else %}
        TRUE
    {% endif %}
