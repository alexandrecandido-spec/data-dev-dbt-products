with daily as (
  select
    d.store_id,
    last_day(d.date)                as mes,      
    d.date, d.sys_audit_updated_on, d.row_key,
    d.platform_type,
    -- métricas diarias
    coalesce(d.orders,0)            as orders,
    coalesce(d.gmv,0)               as gmv,
    coalesce(d.gmv_usd,0)           as gmv_usd,
    coalesce(d.products,0)          as products,
    -- dims mínimas
    d.country,
    -- snapshot candidates (directo de la daily)
    d.current_plan,
    d.historical_plan,
    d.current_bu,
    d.historical_bu,
    d.current_seller_segment,
    d.historical_seller_segment,
    d.max_seller_segment
  from {{ ref('g__operations__orders_gmv_store__agg_daily') }} d
),

-- 1 fila por (store_id, mes): totales + pivot on/off
agg_monthly as (   
  select
    store_id,
    mes,
    sum(orders)  as orders,
    sum(gmv)     as gmv,
    sum(gmv_usd) as gmv_usd,
    sum(products) as products,
    sum(case when platform_type='on'  then orders  else 0 end) as orders_on_platform,
    sum(case when platform_type='off' then orders  else 0 end) as orders_off_platform,
    sum(case when platform_type='on'  then gmv     else 0 end) as gmv_on_platform,
    sum(case when platform_type='off' then gmv     else 0 end) as gmv_off_platform,
    sum(case when platform_type='on'  then gmv_usd else 0 end) as gmv_usd_on_platform,
    sum(case when platform_type='off' then gmv_usd else 0 end) as gmv_usd_off_platform,
    max(sys_audit_updated_on) as max_sys_audit_updated_on_in_month
  from daily
  group by 1,2
),

-- LOM = última fila observada del mes para snapshot (sin cambiar 'mes')
lom_ranked as (
  select
    store_id, mes, country,
    current_plan, historical_plan,
    current_bu, historical_bu,
    current_seller_segment, historical_seller_segment, max_seller_segment,
    date  as last_observed_date_in_month,
    sys_audit_updated_on as lom_sys_audit_updated_on,
    row_number() over (
      partition by store_id, mes
      order by date desc, sys_audit_updated_on desc, row_key desc
    ) as rn
  from daily
),
lom as (select * from lom_ranked where rn = 1)

select
  m.store_id, m.mes,
  -- métricas mensuales
  m.orders, m.gmv, m.gmv_usd, m.products,
  m.orders_on_platform, m.orders_off_platform,
  m.gmv_on_platform, m.gmv_off_platform,
  m.gmv_usd_on_platform, m.gmv_usd_off_platform,

  -- indicadores on/off
  case when m.orders_on_platform  > 0 and coalesce(m.orders_off_platform,0) = 0 then 1 else 0 end as sales_on_platform,
  case when m.orders_off_platform > 0 and coalesce(m.orders_on_platform,0)  = 0 then 1 else 0 end as sales_off_platform,
  case when m.orders_on_platform  > 0 and m.orders_off_platform > 0 then 1 else 0 end as sales_onoff_platform,

  -- apoyo incrementalidad
  m.max_sys_audit_updated_on_in_month,
  -- snapshot LOM tomado de daily
  l.country,
  l.current_plan, l.historical_plan,
  l.current_bu, l.historical_bu,
  l.current_seller_segment, l.historical_seller_segment, l.max_seller_segment,
  l.last_observed_date_in_month, l.lom_sys_audit_updated_on
from agg_monthly m
left join lom l using (store_id, mes)
