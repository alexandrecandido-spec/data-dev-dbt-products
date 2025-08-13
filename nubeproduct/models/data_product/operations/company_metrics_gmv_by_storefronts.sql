{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['datemonth','store_id'],
        on_schema_change='fail',
        partition_by='year_month_code',
        tags=["monthly-1st-10AM"]
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'datemonth', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    source.datemonth,
    source.store_id,
    source.country,
    source.country_currency,
    source.store_creation_date,
    source.is_paying_merchant,

    -- Orders & GMV totals by month
    source.orders_total_month,
    source.gmv_usd_total_month,
    source.gmv_local_total_month,

    -- Renaming metrics to the final product standard (_monthly)
    source.gmv_usd_mobile_month AS gmv_usd_mobile_monthly,
    source.gmv_local_mobile_month AS gmv_local_mobile_monthly,
    source.orders_mobile_month AS orders_mobile_monthly,

    source.gmv_usd_store_month AS gmv_usd_store_monthly,
    source.gmv_local_store_month AS gmv_local_store_monthly,
    source.orders_store_month AS orders_store_monthly,

    source.gmv_usd_form_month AS gmv_usd_form_monthly,
    source.gmv_local_form_month AS gmv_local_form_monthly,
    source.orders_form_month AS orders_form_monthly,

    source.gmv_usd_social_month AS gmv_usd_social_monthly,
    source.gmv_local_social_month AS gmv_local_social_monthly,
    source.orders_social_month AS orders_social_monthly,

    source.gmv_usd_pos_month AS gmv_usd_pos_monthly,
    source.gmv_local_pos_month AS gmv_local_pos_monthly,
    source.orders_pos_month AS orders_pos_monthly,

    source.gmv_usd_api_app12217_month AS gmv_usd_api_app12217_monthly,
    source.gmv_local_api_app12217_month AS gmv_local_api_app12217_monthly,
    source.orders_api_app12217_month AS orders_api_app12217_monthly,

    source.gmv_usd_api_other_apps_month AS gmv_usd_api_other_apps_monthly,
    source.gmv_local_api_other_apps_month AS gmv_local_api_other_apps_monthly,
    source.orders_api_other_apps_month AS orders_api_other_apps_monthly,

    source.gmv_usd_others_month AS gmv_usd_others_monthly,
    source.gmv_local_others_month AS gmv_local_others_monthly,
    source.orders_others_month AS orders_others_monthly,

    -- Metadata and Audit Columns from reference
    CAST(date_format(source.datemonth, 'yyyyMM') AS INT) AS year_month_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_company_metrics_gmv_by_storefront') }} source 
LEFT JOIN existing_data e ON source.store_id = e.store_id and source.datemonth = e.datemonth
WHERE is_paying_merchant = TRUE OR (is_paying_merchant = FALSE AND orders_total_month>0) and 
{% if not is_incremental() %}
    source.datemonth >= '2022-01-01'
{% endif %}
{% if is_incremental() %}
    source.datemonth > COALESCE(
            (SELECT MAX(datemonth) FROM {{ this }}),
            last_day(add_months(current_date(), -1))
        )
{% endif %}
