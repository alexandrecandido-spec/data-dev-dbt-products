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
    SOD.orders_daily,
    SOD.gmv_local_currency_daily,
    SOD.gmv_usd_daily,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_partnerships__agencies_stores_gmv_orders_daily_construction') }} AS SOD   
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

