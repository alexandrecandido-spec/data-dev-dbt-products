{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['store_id', 'order_date'],
        on_schema_change = 'fail',
        tags = ['daily-10am']
) }}

WITH existing_data AS (
    {{ get_existing_data(this, ['store_id', 'order_date', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

SELECT 
    store_id,
    order_date,
    gmv_local_currency_daily,
    gmv_usd_daily,
    orders_daiLY
FROM {{ ref('_int_partners__agencies_stores_orders_daily_construction') }}
WHERE sys_audit_updated_on > (SELECT MAX(sys_audit_updated_on) FROM existing_data)