{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}
with product_list as (
    SELECT 
    year_month_code,
    id,
    store_id,
    publish,
    free_shipping,
    created_at,
    updated_at,
    deleted_at,
    brand,
    gtin,
    mpn,
    gender,
    age_group,
    evaluated_at,
    name_invalid_at,
    suggested_name,
    min_price,
    max_price,
    sold_qty,
    has_stock,
    requires_shipping,
    video_url
    FROM {{ source('stg_catalog', 'mwp_product_list') }} AS mil
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    where sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    year_month_code,
    product_list.id,
    store_id,
    publish,
    free_shipping,
    created_at,
    updated_at,
    deleted_at,
    brand,
    gtin,
    mpn,
    gender,
    age_group,
    evaluated_at,
    name_invalid_at,
    suggested_name,
    min_price,
    max_price,
    sold_qty,
    has_stock,
    requires_shipping,
    video_url,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM product_list
LEFT JOIN existing_data e ON product_list.id = e.id