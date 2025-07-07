{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['id'],
        partition_by=['year_month_day_code'],
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}

select
    --data on orders
    o.id,
    o.fecha_completed_at,
    o.payment_status,
    o.status,
    o.gmv_usd,
    o.year_month_day_code,
    o.was_order_edited,
    o.order_first_edited_at,
    o.order_last_edited_at,
    o.order_edit_count,
    --data on store
    e.store_id,
    e.state,
    e.country,
    e.currency,
    e.current_segment,
    e.first_payment,
    e.churned_at,
    e.grupo,
    e.created_at,
    e.verified,
    e.has_edit_orders_disponible store_has_edit_orders_disponible,
    e.fecha_edit_orders_disponible store_fecha_edit_orders_disponible,
    e.edit_orders_user store_edit_orders_user,
    e.edit_first_use store_edit_first_use,
    e.edit_last_use store_edit_last_use,
    e.edit_count store_edit_count,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_product__edit_orders_orders_usage') }} o
RIGHT JOIN {{ ref('_int_product__edit_orders_stores_enablement_and_usage') }} e on e.store_id = o.store_id
 {% if is_incremental() %}
    WHERE 
        o.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} a )
        or e.sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} a )
    {% endif %}