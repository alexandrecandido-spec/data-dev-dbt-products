with dp as (
  select
    store_id,
    reported_month,
    sum(gmv)              as gmv,
    sum(gmv_usd)          as gmv_usd,
    sum(orders)           as orders,
    sum(product_quantity) as product_quantity
  from {{ ref('g__acquisition__deepdive_gmv_store__agg_monthly') }}
  group by 1,2
),
dy as (
  select
    store_id,
    last_day(date) as reported_month,
    sum(coalesce(gmv,0))      as gmv,
    sum(coalesce(gmv_usd,0))  as gmv_usd,
    sum(coalesce(orders,0))   as orders,
    sum(coalesce(products,0)) as product_quantity
  from {{ ref('g__operations__orders_gmv_store__agg_daily') }}
  group by 1,2
),
cmp as (
  select
    coalesce(dp.store_id, dy.store_id) as store_id,
    coalesce(dp.reported_month, dy.reported_month) as reported_month,
    coalesce(dp.gmv,0)              as dp_gmv,
    coalesce(dy.gmv,0)              as dy_gmv,
    coalesce(dp.gmv_usd,0)          as dp_gmv_usd,
    coalesce(dy.gmv_usd,0)          as dy_gmv_usd,
    coalesce(dp.orders,0)           as dp_orders,
    coalesce(dy.orders,0)           as dy_orders,
    coalesce(dp.product_quantity,0) as dp_products,
    coalesce(dy.product_quantity,0) as dy_products
  from dp
  full outer join dy
    on dp.store_id = dy.store_id
   and dp.reported_month = dy.reported_month
)
select *
from cmp
where
    abs(dp_gmv - dy_gmv) > 0.01
 or abs(dp_gmv_usd - dy_gmv_usd) > 0.01
 or dp_orders  <> dy_orders
 or dp_products <> dy_products