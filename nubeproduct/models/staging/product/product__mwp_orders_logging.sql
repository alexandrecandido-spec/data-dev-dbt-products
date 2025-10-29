{{
    config(
        materialized='table',
        unique_key='id',
        on_schema_change='fail',
        partition_by= 'year_month_code',
        tags=['product','daily-1am']
    )
}}
WITH source AS (
select 
year_month_code,
id,
user_id,
employee_id,
store_id,
order_id,
type,
data_2,
data_3,
extra,
happened_at,
created_at,
updated_at,
app_id,
CONCAT(CAST(DATE(happened_at) AS STRING),'-',CAST(store_id AS STRING)) order_date_store_id,
CAST(date_format(happened_at, 'yyyyMMdd') AS INT) AS year_month_day_code
from {{ source('stg_orders', 'mwp_orders_logging') }}

    {% if is_incremental() %}

    -- this filter will only be applied on an incremental run
    -- (uses >= to include records whose timestamp occurred since the last run of this model)
    -- (If event_time is NULL or the table is truncated, the condition will always be true and load all records)
    WHERE sys_audit_updated_on >= (select coalesce(max(sys_audit_updated_on),'1900-01-01') - INTERVAL '1 hour' from {{ this }} )

     {% endif %}
),
existing_data AS (
    {{ get_existing_data(this, ['id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

select 
    year_month_code,
    s.id,
    user_id,
    employee_id,
    store_id,
    order_id,
    type,
    data_2,
    data_3,
    extra,
    happened_at,
    created_at,
    updated_at,
    app_id,
    order_date_store_id,
    year_month_day_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM source s
LEFT JOIN existing_data e ON s.id = e.id