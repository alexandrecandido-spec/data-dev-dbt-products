{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

select
    store_id,
    state,
    country,
    currency,
    current_segment,
    first_payment,
    churned_at,
    plan_name,
    merchant_created_at,
    has_saved_searches_available,
    saved_searches_available_at,
    saved_searches_first_use,
    saved_searches_last_use,
    saved_searches_count,
    saved_searches_user,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__orders_saved_searches_stores_enabling_tag') }} e
        {% if is_incremental() %}
    WHERE 
        e.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} a )
    {% endif %}