with
orders as (
    select 
        date(completed_at) as registered_date
        ,id as order_id
        ,store_id
        ,payment
        ,shipping
        ,total
        ,total_in_usd
from {{ ref('company_metrics_paid_orders') }} 
),
apps as (
    select
        id as app_id
        ,handle as app_handle
    from {{ ref('moltres__mwp_apps') }}
)
select
  registered_date
  ,store_id
  ,payment as app_name
  ,'payments' as app_category
  ,a.app_id as app_id
  ,count(distinct order_id) as total_orders
  ,sum(total) as total_gmv_local_currency
  ,sum(total_in_usd) as total_gmv_usd
from orders o
inner join apps a
on o.payment = a.app_handle
group by 1,2,3,4,5
----
union all
----
select
  registered_date
  ,store_id
  ,shipping as app_name
  ,'shipping' as app_category
  ,a.app_id as app_id
  ,count(distinct order_id) as total_orders
  ,sum(total) as total_gmv_local_currency
  ,sum(total_in_usd) as total_gmv_usd
from orders o
inner join apps a
on o.shipping = a.app_handle
group by 1,2,3,4,5