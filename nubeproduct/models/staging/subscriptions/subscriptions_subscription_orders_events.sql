{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['order_id', 'status'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with orders as (
  select
      date(created_at) as registered_date
      ,store_id
      ,customer_id
      ,order_id
      ,cast(subscription_id as string) as subscription_id
      ,cast(status as string) as status
      ,instance_number
      ,attempt
      ,cast(case when error_code = '' then null else error_code end as string) as error_code
      ,cast(case when error_description = '' then null else error_description end as string) as error_description
  from {{ source('stg_subscriptions', 'subscription_orders') }}
)
SELECT
    o.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from orders o
{% if is_incremental() %}
  WHERE
  registered_date >= (select coalesce(max(registered_date),'1900-01-01') from {{ this }} )
{% endif %}