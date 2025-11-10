{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'unique_id',
    partition_by = 'registered_date',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

with subscriptions_store_info as (
  select
    registered_date
    ,store_id
    ,store_name
    ,vertical_name
    ,segment
    ,total_metaplans
    ,total_active_metaplans
    ,new_metaplans
    ,new_subscriptions
    ,churned_subscriptions
    ,total_subscriptions
    ,total_active_subscriptions
    ,total_cancelled_subscriptions
    ,total_customers
    ,total_active_customers
    ,total_orders
    ,total_successful_initial_orders
    ,total_successful_recurrent_orders
    ,total_not_successful_initial_orders
    ,total_transactions
    ,failed_transactions
    ,paid_transactions
    ,initial_failed_transactions
    ,initial_paid_transactions
    ,recurrent_failed_transactions
    ,recurrent_paid_transactions
  from {{ ref('_int_product_subscriptions_main_data') }} s
  left join {{ ref('_int_product_subscription_orders') }} so
    on s.registered_date = so.registered_date
    and s.store_id = so.store_id
)
select
  concat(
        cast(registered_date as string), '_'
        ,cast(store_id as string)
    ) as unique_id
  ,s.*
  ,current_timestamp as sys_audit_created_on
  ,'data-dev-dbt-products' as sys_audit_created_by
  ,current_timestamp as sys_audit_updated_on
  ,'data-dev-dbt-products' as sys_audit_updated_by
from subscriptions_store_info s 
where 
{% if is_incremental() %}
  registered_date >= (select coalesce(max(registered_date),'1900-01-01') from {{ this }} )
{% endif %}