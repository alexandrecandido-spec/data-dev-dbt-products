with monthly as (
  -- una fila por mes SOLO si hubo actividad (ventas) en ese mes
  select store_id, mes, gmv, gmv_usd
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }}
),

ranked as (
  -- últimos 3 meses con actividad por tienda
  select
    store_id, mes, gmv, gmv_usd,
    row_number() over (partition by store_id order by mes desc) as rn
  from monthly
),

last3 as (
  select store_id, gmv, gmv_usd
  from ranked
  where rn <= 3
)

select
  store_id,
  avg(gmv)     as avg_gmv_last_3_months,
  avg(gmv_usd) as avg_gmv_usd_last_3_months
from last3
group by 1
