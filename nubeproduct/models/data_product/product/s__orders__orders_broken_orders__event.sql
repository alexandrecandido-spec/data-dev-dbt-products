{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['order_id','issue_type'],
        on_schema_change='fail',
        tags=["daily-9am"]
    )
}}

SELECT
store_id, 
domain,
order_id,
contact_email,
created_at,
completed_at, 
payment_status ,
order_status,
storefront,
country,
current_segment,
issue_type,
current_timestamp AS sys_audit_created_on,
'data-dev-dbt-products' AS sys_audit_created_by,
current_timestamp AS sys_audit_updated_on,
'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int__product__broken_orders') }} o
   {% if is_incremental() %}
WHERE o.max_sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }})
    {% endif %}
