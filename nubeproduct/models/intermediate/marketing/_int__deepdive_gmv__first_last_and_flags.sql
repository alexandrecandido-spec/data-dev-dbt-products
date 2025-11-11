with base as (
  -- lista de (store_id, mes) existentes en la capa base mensual
  select store_id, mes
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }}
),

by_day as (
  -- días con venta (orders>0 o gmv>0)
  select
    d.store_id,
    cast(d.date as date) as date
  from {{ ref('g__operations__orders_gmv_store__agg_daily') }} d
  where coalesce(d.orders, 0) > 0 or coalesce(d.gmv, 0) > 0
  group by 1, 2
),

first_last as (
  -- primera y última venta all-time por store
  select
    store_id,
    min(date)            as first_sale_date_all_time,
    min(last_day(date))  as first_sale_month_all_time,
    max(date)            as last_sale_date,
    max(last_day(date))  as last_sale_month
  from by_day
  group by 1
)

select
  b.store_id,
  b.mes,
  fl.first_sale_date_all_time,
  fl.first_sale_month_all_time,
  fl.last_sale_date,
  fl.last_sale_month,
  case when b.mes = fl.first_sale_month_all_time then 1 else 0 end as is_first_sale_month,
  case when b.mes = fl.last_sale_month          then 1 else 0 end as is_last_sale_month
from base b
left join first_last fl using (store_id)
