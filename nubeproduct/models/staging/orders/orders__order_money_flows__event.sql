{{
    config(
        materialized='incremental',
        unique_key='id',
        partition_by='year_month_day_code',
        on_schema_change='fail',
        tags=["operations","daily-8am-8pm"]
    )
}}

WITH source AS (
    SELECT 
        id,
        store_id,
        order_id,
        currency,
        amount,
        amount_usd,
        o.hash,
        source,
        payment_transaction_id,
        payment_transaction_event_id,
        happened_at,
        effective_amount,
        effective_amount_usd,
        sys_audit_created_on,
        sys_audit_created_by,
        sys_audit_updated_by,
        sys_audit_updated_on,
        CAST(date_format(happened_at, 'yyyyMMdd') AS INT) AS year_month_day_code
FROM {{ source('stg_orders', 'order_money_flows') }} o
    
    {% if is_incremental() %}
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 hour' from {{ this }} )

    {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
    source.id,
    source.store_id,
    source.order_id,
    source.currency,
    source.amount,
    source.amount_usd,
    source.hash,
    source.source,
    source.payment_transaction_id,
    source.payment_transaction_event_id,
    source.happened_at,
    source.effective_amount,
    source.effective_amount_usd,
    source.year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source
LEFT JOIN existing_data e ON source.id = e.id