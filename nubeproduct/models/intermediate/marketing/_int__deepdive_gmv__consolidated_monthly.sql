with base as (
  select
    m.store_id,
    m.mes as reported_month,

    -- métricas núcleo y pivots on/off
    m.orders, m.gmv, m.gmv_usd, m.products,
    m.orders_on_platform, m.orders_off_platform,
    m.gmv_on_platform, m.gmv_off_platform,
    m.gmv_usd_on_platform, m.gmv_usd_off_platform,

    -- soporte incrementalidad/audit
    m.max_sys_audit_updated_on_in_month,
    m.country,
    m.current_plan, m.historical_plan,
    m.current_bu,   m.historical_bu,
    m.current_seller_segment, m.historical_seller_segment, m.max_seller_segment,
    m.last_observed_date_in_month,
    m.lom_sys_audit_updated_on
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }} m
),

flg as (
  select *
  from {{ ref('_int__deepdive_gmv__first_last_and_flags') }}
),

avg3 as (
  select *
  from {{ ref('_int__deepdive_gmv__avg3m_constants') }}
),

rng as (
  select *
  from {{ ref('_int__deepdive_gmv__ranges') }}
),

ten as (
  select *
  from {{ ref('_int__deepdive_gmv__tenure_from_lifecycle') }}
),

nvc as (
  select *
  from {{ ref('_int__deepdive_gmv__gmv_new_vs_churned') }}
)

select
  -- claves
  base.store_id,
  base.reported_month,

  -- métricas núcleo 
  base.gmv,
  base.gmv_usd,
  base.orders,
  base.products                                        as product_quantity,
  case when base.orders > 0 then base.gmv     / base.orders end  as avg_ticket,
  case when base.orders > 0 then base.gmv_usd / base.orders end  as avg_ticket_usd,

  -- desgloses on/off platform
  base.orders_on_platform,
  base.orders_off_platform,
  base.gmv_on_platform,
  base.gmv_off_platform,
  base.gmv_usd_on_platform,
  base.gmv_usd_off_platform,

  -- promedios 3 meses CERRADOS (constantes por store)
  avg3.avg_gmv_last_3_months,
  avg3.avg_gmv_usd_last_3_months,

  -- rangos
  rng.gmv_local_monthly_range,
  rng.gmv_usd_monthly_range,
  rng.gmv_local_current_range,
  rng.gmv_usd_current_range,

  -- first/last + flags
  flg.first_sale_date_all_time,
  flg.first_sale_month_all_time,
  flg.last_sale_date,
  flg.last_sale_month,
  flg.is_first_sale_month,
  flg.is_last_sale_month,

  -- clasificación
  nvc.gmv_new_vs_churned,

  -- plan / BU / histórico / segmento 
  base.current_plan,
  base.current_bu,
  base.historical_plan,
  base.historical_bu,
  base.current_seller_segment,

  -- tenure 
  ten.months_from_creation,
  ten.months_from_first_payment,
  ten.months_from_first_seller,
  ten.months_from_first_sale,
  ten.months_from_new_seller,

  -- soporte para incrementalidad del DP
  base.max_sys_audit_updated_on_in_month,
  base.lom_sys_audit_updated_on,
  base.last_observed_date_in_month

from base
left join flg
  on flg.store_id       = base.store_id
 and flg.reported_month = base.reported_month
left join avg3 using (store_id)
left join rng
  on  rng.store_id = base.store_id
  and rng.mes      = base.reported_month
left join ten
  on  ten.store_id = base.store_id
  and ten.mes      = base.reported_month   
left join nvc
  on  nvc.store_id = base.store_id
  and nvc.mes      = base.reported_month