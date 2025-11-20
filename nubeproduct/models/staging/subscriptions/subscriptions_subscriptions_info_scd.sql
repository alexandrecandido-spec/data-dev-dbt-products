{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['unique_id'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with subscriptions as (
      select
      cast(id as string) as subscription_id
      ,cast(subscription_option_id as string) as subscription_option_id
      ,store_id
      ,customer_id
      ,initial_order_id
      ,cast(email as string) as customer_mail
      ,cast(status as string) as subscription_status
      ,date(initial_date) as initial_subscription_date
      ,date(created_at) as subscription_created_date
      ,date(cancellation_date) as subscription_cancellation_date
  from {{ source('stg_subscriptions', 'subscriptions') }}
)
SELECT
    concat(cast(subscription_id as string), '_', cast(subscription_status as string)) as unique_id
    ,s.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from subscriptions s
{% if is_incremental() %}
  WHERE
  initial_subscription_date >= (select coalesce(max(initial_subscription_date),'1900-01-01') from {{ this }} )
{% endif %}