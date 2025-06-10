{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['datemonth','store_id'],
        on_schema_change='fail',
        partition_by='year_month_code',
        tags=["monthly-1st-9AM"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'datemonth', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.datemonth,
    source.store_id,
    country,
    country_currency,
    created_at,
    proportional_segment,
    is_paying_merchant,
    orders_general_month AS orders_monthly,
    gmv_general_month AS gmv_usd_monthly,
    gmv_local_general_month AS gmv_local_currency_monthly,
    orders_general_90d,
    CASE
        WHEN orders_general_90d * proportional > 1500 THEN 'top-seller'
        WHEN orders_general_90d * proportional BETWEEN 751 AND 1500 THEN 'large-seller'
        WHEN orders_general_90d * proportional BETWEEN 151 AND 750 THEN 'medium-seller'
        WHEN orders_general_90d * proportional BETWEEN 31 AND 150 THEN 'small-seller'
        WHEN orders_general_90d * proportional BETWEEN 7 AND 30 THEN 'tiny-seller'
        WHEN orders_general_90d * proportional BETWEEN 1 AND 6 THEN 'struggling-seller'
        ELSE 'no-seller'
    END AS segment,
    orders_on_platform_month AS orders_on_platform_monthly,
    gmv_on_platform_month AS gmv_usd_on_platform_monthly,
    gmv_local_on_platform_month AS gmv_local_currency_on_platform_monthly,
    orders_on_platform_90d,
    CASE
        WHEN orders_on_platform_90d * proportional > 1500 THEN 'top-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 751 AND 1500 THEN 'large-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 151 AND 750 THEN 'medium-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 31 AND 150 THEN 'small-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 7 AND 30 THEN 'tiny-seller'
        WHEN orders_on_platform_90d * proportional BETWEEN 1 AND 6 THEN 'struggling-seller'
        ELSE 'no-seller'
    END AS segment_on_platform,
    orders_off_platform_month AS orders_off_platform_monthly,
    gmv_off_platform_month AS gmv_usd_off_platform_monthly,
    gmv_local_off_platform_month AS gmv_local_currency_off_platform_monthly,
    orders_off_platform_90d,
    CASE
        WHEN orders_off_platform_90d * proportional > 1500 THEN 'top-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 751 AND 1500 THEN 'large-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 151 AND 750 THEN 'medium-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 31 AND 150 THEN 'small-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 7 AND 30 THEN 'tiny-seller'
        WHEN orders_off_platform_90d * proportional BETWEEN 1 AND 6 THEN 'struggling-seller'
        ELSE 'no-seller'
    END AS segment_off_platform,
    CAST(date_format(source.datemonth, 'yyyyMM') AS INT) AS year_month_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_company_metrics_gmv_and_segments__window_sales') }} source 
LEFT JOIN existing_data e ON source.store_id = e.store_id and source.datemonth = e.datemonth
WHERE is_paying_merchant = TRUE OR (is_paying_merchant = FALSE AND orders_general_90d>0) and 
{% if not is_incremental() %}
    source.datemonth >= '2022-01-01'
{% endif %}
{% if is_incremental() %}
    source.datemonth > COALESCE(
            (SELECT MAX(datemonth) FROM {{ this }}),
            last_day(add_months(current_date(), -1))
        )
{% endif %}
