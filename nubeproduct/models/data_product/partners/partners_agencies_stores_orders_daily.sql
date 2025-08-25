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
)

SELECT 
    SOD.store_id,
    SOD.order_date,
    COALESCE(SOD.gmv_local_currency_daily, 0) AS gmv_local_currency_daily,
    COALESCE(SOD.gmv_usd_daily, 0) AS gmv_usd_daily,
    COALESCE(SOD.orders_daily, 0) AS orders_daily,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_partners__agencies_stores_orders_daily_construction') }} AS SOD   
LEFT JOIN existing_data AS e
    ON SOD.store_id = e.store_id
    AND SOD.order_date = e.order_date
    {% if is_incremental() %}
WHERE    
      SOD.construction_change_timestamp > 
        (
            SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
            FROM {{ this }}
        )
    {% endif %}

