{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['unique_id'],
        on_schema_change='fail',
        tags=["daily-8am"]
    )
}}

with potential_clients as (
    SELECT 
        store_id
        ,store_name
        ,vertical_name
        ,country_name
        ,customer_id
        ,contact_name
        ,product_id
        ,product_name
        ,avg_product_price
        ,last_price
        ,total_orders
        ,avg_order_frequency
    FROM {{ ref('_int__subscriptions_store_users') }}
)
select distinct
    concat(cast(store_id as string), '_', cast(customer_id as string), '_', cast(product_id as string)) as unique_id
    ,p.*
    ,to_timestamp('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}') as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,to_timestamp('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}') as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from potential_clients p
{% if is_incremental() %}
-- Rely on dbt's MERGE with unique_key to handle upserts efficiently
{% endif %}