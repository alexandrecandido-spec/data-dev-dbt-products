WITH
subs_orders as (
  select
      date(created_at) as registered_date
      ,store_id
      ,customer_id
      ,order_id
      ,subscription_id
      ,status
      ,instance_number
      ,attempt
      ,case when error_code = '' then null else error_code end as error_code
      ,case when error_description = '' then null else error_description end as error_description
  from {{ ref('subscriptions_subscription_orders_scd') }}
),
orders as (
SELECT 
  t.externalorderid as order_id
  ,o.total_ammount 
  ,o.total_ammount_usd
  ,order_traits
  ,count(distinct t.id) as total_transactions
  ,count(distinct case when status = 'failed' then t.id end) as failed_transactions
  ,count(distinct case when status = 'paid' then t.id end) as paid_transactions
FROM {{ ref('product__nuvem_pago__transactions__events') }} t
inner join (
            select 
              id as order_id
              ,total_in_local_currency as total_ammount
              ,total_in_usd as total_ammount_usd
              ,order_traits
          from {{ ref('s__orders__carts_orders_heads__events') }}
          where created_at >= date('2025-09-01')
          and order_traits is not null
          ) o
  on t.externalorderid = o.order_id
group by 1,2,3,4
),
subs_orders_final as (
  select
    so.registered_date
    ,so.store_id
    ,so.order_id
    ,o.order_traits
    ,so.customer_id
    ,so.subscription_id
    ,so.status
    ,so.instance_number
    ,so.attempt
    ,o.total_transactions
    ,o.failed_transactions
    ,o.paid_transactions
    ,o.failed_transactions_percentage
    ,o.total_ammount as gmv_local
    ,o.total_ammount_usd as gmv_usd
  from subs_orders so 
  inner join orders o
    on so.order_id = o.order_id
)
select
  registered_date
  ,store_id
  ,count(distinct order_id) as total_orders
  ,count(distinct case when order_traits = 'subscription_initial' and status = 'SUCCESSFUL' then order_id end) as total_successful_initial_orders
  ,count(distinct case when order_traits = 'subscription_recurrence' and status = 'SUCCESSFUL' then order_id end) as total_successful_recurrent_orders
  ,count(distinct case when order_traits = 'subscription_initial' and status != 'SUCCESSFUL' then order_id end) as total_not_successful_initial_orders
  ,sum(total_transactions) as total_transactions
  ,sum(failed_transactions) as failed_transactions
  ,sum(paid_transactions) as paid_transactions
  ,coalesce(sum(case when order_traits = 'subscription_initial' then failed_transactions end),0) as initial_failed_transactions
  ,coalesce(sum(case when order_traits = 'subscription_initial' then paid_transactions end),0) as initial_paid_transactions
  ,coalesce(sum(case when order_traits = 'subscription_recurrence' then failed_transactions end),0) as recurrent_failed_transactions
  ,coalesce(sum(case when order_traits = 'subscription_recurrence' then paid_transactions end),0) as recurrent_paid_transactions
from subs_orders_final
group by 1,2