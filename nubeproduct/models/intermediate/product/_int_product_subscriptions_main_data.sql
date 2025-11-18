with 
dates as (
  select distinct
    date_id as registered_date
  from {{ ref('dim_calendar') }}
  where date(first_day_of_month) >= date('2025-09-01')
),
stores as (
  select
    date(date_add(DAY, 1, datemonth)) as registered_month
    ,c.store_id
    ,m.domain as store_name
    ,m.vertical_name
    ,is_paying_merchant
    ,segment
  from {{ ref('company_metrics_gmv_and_segments') }} c
  left join {{ ref('company_metrics_merchant_info') }} m
    on c.store_id = m.store_id 
),
metaplans (
  select 
    created_date as metaplan_created_date
    ,store_id
    ,promotion_id
    ,metaplan_id
    ,metaplan_name
    ,is_metaplan_deleted
  from {{ ref('subscriptions_metaplans_scd') }}
),
subscription as (
  select
      subscription_id
      ,subscription_option_id
      ,store_id
      ,customer_id
      ,initial_order_id
      ,customer_mail
      ,subscription_status
      ,initial_subscription_date
      ,subscription_created_date
      ,subscription_cancellation_date
  from {{ ref('subscriptions_subscriptions_info_scd') }}
),
subs_option as (
    select
      creation_date as subs_option_creation_date
      ,subs_option_id
      ,metaplan_id
      ,frequency_type
      ,frequency_param
      ,discount_percentage
      ,is_subs_option_deleted
    from {{ ref('subscriptions_subscription_options_scd') }}
),
subs_runs as (
    select
        subscription_id
        ,instance_number
        ,attempt
        ,status as subs_run_status
        ,next_attempt_date
        ,next_instance_date
    from {{ ref('subscriptions_runs_upcoming_scd') }}
),
subscription_final as (
  select
      s.subscription_id
      ,subscription_status
      ,m.metaplan_id
      ,m.metaplan_created_date
      ,is_metaplan_deleted
      ,m.store_id
      ,st.store_name
      ,st.vertical_name
      ,st.segment
      ,customer_id
      ,s.subscription_created_date
      ,initial_subscription_date
      ,subscription_cancellation_date
      ,initial_order_id
      ,frequency_type
      ,frequency_param
      ,discount_percentage
      ,sr.instance_number
      ,sr.attempt
      ,sr.subs_run_status
      ,sr.next_attempt_date
      ,sr.next_instance_date
  from metaplans m
  left join stores st
    on m.store_id = st.store_id
  left join subscription s
    on m.store_id = s.store_id
  left join subs_option so
      on s.subscription_option_id = so.subs_option_id
      and m.metaplan_id = so.metaplan_id
  left join subs_runs sr
      on s.subscription_id = sr.subscription_id
),
subscription_dates as (
  select
    d.registered_date
    ,s.*
  from subscription_final s
  cross join dates d
  where registered_date between date_trunc('month', metaplan_created_date) and coalesce(s.subscription_cancellation_date, '2100-01-01')
)
select
  registered_date
  ,store_id
  ,store_name
  ,vertical_name
  ,segment
  ,count(distinct metaplan_id) as total_metaplans
  ,count(distinct case when  registered_date >= metaplan_created_date and is_metaplan_deleted is false then metaplan_id end) as total_active_metaplans
  ,count(distinct case when metaplan_created_date = registered_date then metaplan_id end) as new_metaplans
  ,count(distinct case when registered_date = initial_subscription_date then subscription_id end) as new_subscriptions
  ,count(distinct case when registered_date = subscription_cancellation_date then subscription_id end) as churned_subscriptions
  ,count(distinct subscription_id) as total_subscriptions
  ,count(distinct case when subscription_status = 'ACTIVE' then subscription_id end) as total_active_subscriptions
  ,count(distinct case when subscription_status = 'CANCELLED' then subscription_id end) as total_cancelled_subscriptions
  ,count(distinct customer_id) as total_customers
  ,count(distinct case when subscription_cancellation_date is null then customer_id end) as total_active_customers
from subscription_dates
group by 1,2,3,4,5