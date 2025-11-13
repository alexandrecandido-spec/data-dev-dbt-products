{{
    config(
        materialized='incremental',
        unique_key='coupon_id',
        partition_by='year_month_day_code',
        on_schema_change='fail',
        tags=["product","daily-9am"]
    )
}}


WITH source AS (
    SELECT 
        id,
        store_id,
        code,
        type,
        valid,
        start_date,
        end_date,
        deleted_at,
        used,
        max_uses,
        value,
        restriction,
        apply_total_amount,
        created_at,
        updated_at,
        created_by_app_id,
        first_consumer_purchase,
        max_uses_per_client,
        combines_with_other_discounts,
        only_cheapest_shipping,
        CAST(date_format(created_at, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM {{ source('stg_moltres', 'mwp_discount_coupons') }}
    {% if is_incremental() %}
    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 hour' from {{ this }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['coupon_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.id coupon_id,
    source.store_id,
    source.code coupon_code,
    source.type coupon_type,
    source.valid coupon_valid,
    source.start_date coupon_start_date,
    source.end_date coupon_end_date,
    source.deleted_at coupon_deleted_at,
    source.used coupon_used,
    source.max_uses coupon_max_uses,
    source.value coupon_value,
    source.restriction coupon_restrictions,
    source.apply_total_amount coupon_apply_total_amount,
    source.created_at coupon_created_at,
    source.updated_at coupon_updated_at,
    source.created_by_app_id coupon_created_by_app_id,
    source.first_consumer_purchase coupon_first_consumer_purchase,
    source.max_uses_per_client coupon_max_uses_per_client,
    source.combines_with_other_discounts coupon_combines_with_other_discounts,
    source.only_cheapest_shipping coupon_only_cheapest_shipping,
    source.year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.id = e.coupon_id