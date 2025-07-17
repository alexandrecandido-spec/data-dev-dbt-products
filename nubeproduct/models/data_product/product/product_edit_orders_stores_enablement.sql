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
    created_at,
    verified,
    has_edit_orders_available,
    edit_orders_available_at,
    edit_orders_user,
    edit_first_use,
    edit_last_use,
    edit_count,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__edit_orders_stores_enablement_and_usage') }} e
        {% if is_incremental() %}
    WHERE 
        e.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} a )
    {% endif %}