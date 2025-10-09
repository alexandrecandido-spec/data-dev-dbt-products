{{
    config(
        materialized='incremental',
        unique_key='id',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}
with product_categories as (
    SELECT 
        id,
        store_id,
        category_parent,
        order,
        created_at,
        updated_at,
        deleted_at,
        google_shopping_category,
        matpath,
        sort_by,
        min_price
    FROM {{ source('stg_catalog', 'mwp_product_categories') }} AS mpc
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') from {{ this }} )
    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    product_categories.id,
    store_id,
    category_parent,
    order,
    created_at,
    updated_at,
    deleted_at,
    google_shopping_category,
    matpath,
    sort_by,
    min_price,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM product_categories
LEFT JOIN existing_data e ON product_categories.id = e.id