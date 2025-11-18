{{
    config(
        materialized='incremental',
        unique_key='promotional_discount_id',
        partition_by='year_month_code',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}


WITH source AS (
    SELECT 
        year_month_code,
        id,
        store_id,
        order_id,
        currency,
        contents,
        total_discount_amount,
        content_items
    FROM {{ source('stg_moltres', 'mwp_promotional_discounts') }}
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 hour' from {{ this }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['promotional_discount_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.year_month_code,
    source.id promotional_discount_id,
    source.store_id,
    source.order_id,
    source.currency,
    source.contents promotional_discount_contents,
    source.total_discount_amount,
    source.content_items,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.id = e.promotional_discount_id