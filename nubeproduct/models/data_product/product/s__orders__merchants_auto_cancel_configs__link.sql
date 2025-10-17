{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['unique_key'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

select
    unique_key,
    store_id,
    state,
    current_segment,
    country,
    plan,
    has_nuvempago,
    has_pagonube,
    has_configed_feature,
    first_config_at,
    overall_active,
    last_overall_change_at,
    update_stock,
    pre_notify_client,
    notify_client,
    payment_status,
    payment_method_active,
    last_change_at,
    payment_method,
    expiration_time,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__auto_cancel_store_level') }} sl
 {% if is_incremental() %}
    WHERE 
        sl.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} a )
    {% endif %}