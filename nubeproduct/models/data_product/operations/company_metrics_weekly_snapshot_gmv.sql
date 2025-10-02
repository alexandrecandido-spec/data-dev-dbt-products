-- Owner: Guille De Felice

{{
    config(
        materialized='incremental',
        unique_key=['date_from', 'store_id'],
        incremental_strategy='append',
        on_schema_change='fail',
        tags=['weekly-monday-10am']
    )
}}

SELECT 
    store_id,
    date_from,
    snapshot_orders_weekly,
    snapshot_gmv_usd_weekly,
    snapshot_gmv_local_currency_weekly,

    -- On Platform
    snapshot_orders_on_platform_weekly,
    snapshot_gmv_usd_on_platform_weekly,
    snapshot_gmv_local_currency_on_platform_weekly,

    -- Off Platform
    snapshot_orders_off_platform_weekly,
    snapshot_gmv_usd_off_platform_weekly,
    snapshot_gmv_local_currency_off_platform_weekly,

    -- Metrics by Storefront: mobile
    snapshot_gmv_usd_mobile_weekly,
    snapshot_gmv_local_mobile_weekly,
    snapshot_orders_mobile_weekly,

    -- store
    snapshot_gmv_usd_store_weekly,
    snapshot_gmv_local_store_weekly,
    snapshot_orders_store_weekly,

    -- form
    snapshot_gmv_usd_form_weekly,
    snapshot_gmv_local_form_weekly,
    snapshot_orders_form_weekly,

    -- social
    snapshot_gmv_usd_social_weekly,
    snapshot_gmv_local_social_weekly,
    snapshot_orders_social_weekly,

    -- pos
    snapshot_gmv_usd_pos_weekly,
    snapshot_gmv_local_pos_weekly,
    snapshot_orders_pos_weekly,

    -- API - App Specific (12217)
    snapshot_gmv_usd_api_app12217_weekly,
    snapshot_gmv_local_api_app12217_weekly,
    snapshot_orders_api_app12217_weekly,

    -- API - Other Apps
    snapshot_gmv_usd_api_other_apps_weekly,
    snapshot_gmv_local_api_other_apps_weekly,
    snapshot_orders_api_other_apps_weekly,

    -- Others
    snapshot_gmv_usd_others_weekly,
    snapshot_gmv_local_others_weekly,
    snapshot_orders_others_weekly,

    -- Audit
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by

FROM 
    {{ ref('_int_company_metrics_gmv_by_storefront__weekly') }}

{% if is_incremental() %}
WHERE
    date_from > (
        SELECT max(date_from) 
        FROM {{ this }} 
        )
{% endif %}