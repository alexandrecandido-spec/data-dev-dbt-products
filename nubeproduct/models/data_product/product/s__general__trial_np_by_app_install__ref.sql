{{
    config(
        materialized='incremental',
        unique_key='store_id',
        incremental_strategy='merge',
        on_schema_change='fail', 
        tags=['daily-10am'] 
    )
}}

WITH base AS (
    SELECT
        store_id,
        created_at,
        country,
        first_payment,
        is_affiliate,
        is_store_blocked,
        option_value,
        is_app_installed,
        app_installed_at,
        device
    FROM {{ ref('_int_product__growth_trial_np_by_app_install') }}
),

existing_data AS (
    {{ get_existing_data(this, [
        'store_id', 
        'sys_audit_created_on', 
        'sys_audit_created_by'
    ]) }}
)

SELECT
    b.store_id,
    b.created_at,
    b.country,
    b.first_payment,
    b.is_affiliate,
    b.is_store_blocked,
    b.option_value,
    b.is_app_installed,
    b.app_installed_at,
    b.device,
    COALESCE(e.sys_audit_created_on, current_timestamp()) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp() AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM base b
LEFT JOIN existing_data e
    ON b.store_id = e.store_id