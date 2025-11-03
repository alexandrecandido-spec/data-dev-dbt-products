{{
    config(
        materialized='incremental',
        unique_key=['date', 'country', 'device', 'is_affiliate', 'is_store_blocked', 'days_agg'],
        incremental_strategy='merge',
        on_schema_change='fail', 
        tags=['daily-10am'] 
    )
}}

WITH base AS (
    SELECT
        date,
        country,
        device,
        is_affiliate,
        is_store_blocked,
        days_agg,
        stores,
        trials
    FROM {{ ref('_int_product__growth_cvr_n_dias') }}
),

existing_data AS (
    {{ get_existing_data(this, [
        'date', 
        'country', 
        'device', 
        'is_affiliate',
        'is_store_blocked',
        'days_agg',
        'sys_audit_created_on', 
        'sys_audit_created_by'
    ]) }}
)

SELECT
    b.date,
    b.country,
    b.device,
    b.is_affiliate,
    b.is_store_blocked,
    b.days_agg,
    b.stores,
    b.trials,
    COALESCE(e.sys_audit_created_on, current_timestamp()) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp() AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM base b
LEFT JOIN existing_data e
    ON b.date = e.date
    AND b.country = e.country
    AND b.device = e.device
    AND b.is_affiliate = e.is_affiliate
    AND b.is_store_blocked = e.is_store_blocked
    AND b.days_agg = e.days_agg