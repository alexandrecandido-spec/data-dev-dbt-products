{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'date_store_app_id',
    partition_by = 'registered_date',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

WITH base AS (
    SELECT
        concat(cast(registered_date as string), '_', cast(store_id as string), '_', cast(app_id as string)) as date_store_app_id
        ,registered_date
        ,store_id
        ,app_name
        ,app_category
        ,app_id
        ,total_orders
        ,total_gmv_local_currency
        ,total_gmv_usd
        ,current_timestamp AS sys_audit_created_on
        ,'data-dev-dbt-products' AS sys_audit_created_by
        ,current_timestamp AS sys_audit_updated_on
        ,'data-dev-dbt-products' AS sys_audit_updated_by
    from {{ref ('_int_platform_app_orders')}}
)
select
    *   
from base
{% if is_incremental() %}
WHERE registered_date >= (select coalesce(max(registered_date),'1900-01-01') from {{ this }} )
    {% endif %}