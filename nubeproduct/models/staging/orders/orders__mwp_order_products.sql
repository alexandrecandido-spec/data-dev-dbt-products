{{ config(
    materialized = 'incremental',
    unique_key = ['id'],
    incremental_strategy = 'merge',
    tags=["operations","daily-9am-9pm"]
) }}

with source as (
    select
        id,
        order_id,
        product_id,
        quantity,
        created_at,
        updated_at,
        TO_TIMESTAMP(deleted_at, 'yyyy-MM-dd HH:mm:ss') AS deleted_at,
        CAST(date_format(created_at, 'yyyyMMdd') AS INT) AS year_month_day_code
    from {{ source('stg_orders', 'mwp_order_products') }}
    where
    {% if not is_incremental() %}
     created_at >= '2018-01-01'
    {% endif %}
    {% if is_incremental() %}
     sys_audit_updated_on > (select max(sys_audit_updated_on) from {{ this }})
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['order_id', 'product_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)


select
    source.id,
    source.order_id,
    source.product_id,
    source.quantity,
    source.created_at,
    source.updated_at,
    source.deleted_at,
    source.year_month_day_code,
    greatest(source.created_at, source.updated_at, source.deleted_at) as change_timestamp,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from source
LEFT JOIN existing_data e ON source.order_id = e.order_id AND source.product_id = e.product_id