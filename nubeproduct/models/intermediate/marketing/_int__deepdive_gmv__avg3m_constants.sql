with monthly as (
  select store_id, mes, gmv, gmv_usd
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }}
),

bounds as (
  -- último mes CERRADO (fin del mes anterior al actual)
  select last_day(add_months(current_date, -1)) as max_closed_mes
),

last3 as (
  -- tomamos únicamente meses CERRADOS, y nos quedamos con los últimos 3
  select m.mes
  from (select distinct mes from monthly) m
  cross join bounds b
  where m.mes <= b.max_closed_mes
  order by m.mes desc
  limit 3
),

filtered as (
  select m.*
  from monthly m
  join last3 l using (mes)
)

select
  store_id,
  avg(gmv)     as avg_gmv_last_3_months,
  avg(gmv_usd) as avg_gmv_usd_last_3_months
from filtered
group by 1
