with base as (
  -- universo (store_id, mes) ya consolidado por mes calendario
  select store_id, mes
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }}
),

fl as (
  -- first/last + flags ahora con reported_month
  select
    store_id,
    reported_month,
    first_sale_date_all_time,
    first_sale_month_all_time,
    last_sale_date,
    last_sale_month,
    is_first_sale_month,
    is_last_sale_month
  from {{ ref('_int__deepdive_gmv__first_last_and_flags') }}
),

lifecycle as (
  -- churned_at directo del lifecycle
  select
    store_id,
    cast(churned_at as date) as churned_at
  from {{ ref('s__lifecycle__store_status__ref') }}
),

bu as (
  -- traemos BU histórico/actual desde la monthly base
  select store_id, mes, current_bu, historical_bu
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }}
),

cls as (
  -- clasificación “gmv_new_vs_churned” (igual que antes)
  select
    b.store_id,
    b.mes,
    case
      when fl.is_first_sale_month = 1 and fl.is_last_sale_month = 1
           and date_trunc('month', b.mes) = date_trunc('month', lc.churned_at)
        then 'Started & Stopped Selling & Churned this month'
      when fl.is_first_sale_month = 1 and fl.is_last_sale_month = 1
           and lc.churned_at is not null
           and date_trunc('month', lc.churned_at) > date_trunc('month', b.mes)
        then 'Started & Stopped Selling this month & Churned later'
      when fl.is_first_sale_month = 1 and fl.is_last_sale_month = 1
           and (lc.churned_at is null or date_trunc('month', lc.churned_at) < date_trunc('month', b.mes))
           and date_trunc('month', b.mes) <> date_trunc('month', current_date)
        then 'Started & Stopped Selling this month'
      when fl.is_first_sale_month = 1
           and date_trunc('month', b.mes) = date_trunc('month', current_date)
        then 'Started Selling this month'
      when fl.is_first_sale_month = 1
        then 'Started Selling this month'
      when fl.is_first_sale_month = 0 and fl.is_last_sale_month = 0
        then 'Ongoing'
      when fl.is_last_sale_month = 1
           and date_trunc('month', b.mes) = date_trunc('month', lc.churned_at)
        then 'Stopped Selling & Churned this month'
      when fl.is_last_sale_month = 1
           and lc.churned_at is not null
           and date_trunc('month', lc.churned_at) > date_trunc('month', b.mes)
        then 'Stopped Selling this month & Churned later'
      when fl.is_last_sale_month = 1
           and (lc.churned_at is null or date_trunc('month', lc.churned_at) < date_trunc('month', b.mes))
           and date_trunc('month', b.mes) <> date_trunc('month', current_date)
        then 'Stopped Selling this month'
      when fl.is_last_sale_month = 1
           and date_trunc('month', b.mes) = date_trunc('month', current_date)
        then 'Ongoing'
      else 'Ongoing'
    end as gmv_new_vs_churned
  from base b
  left join fl
    on fl.store_id = b.store_id
   and fl.reported_month = b.mes
  left join lifecycle lc using (store_id)
)

select
  c.store_id,
  c.mes,
  c.gmv_new_vs_churned,

  -- 🔹 movimientos SMB usando BU histórico/actual + texto de churn
  case
    when coalesce(b.historical_bu,'SMB') = 'MM'
     and coalesce(b.current_bu,'SMB')    = 'SMB' then 'MM → SMB'
    when coalesce(b.historical_bu,'SMB') = 'SMB'
     and coalesce(b.current_bu,'SMB')    = 'MM'  then 'SMB → MM'
    when coalesce(b.historical_bu,'SMB') = 'SMB'
     and instr(lower(coalesce(c.gmv_new_vs_churned,'')), 'stopped selling') > 0
      then c.gmv_new_vs_churned
    when coalesce(b.historical_bu,'SMB') = 'SMB'
     and instr(lower(coalesce(c.gmv_new_vs_churned,'')), 'started selling') > 0
     and instr(lower(coalesce(c.gmv_new_vs_churned,'')), 'stopped selling')  = 0
      then 'Started Selling'
    when coalesce(b.historical_bu,'SMB') = 'SMB'
     and instr(lower(coalesce(c.gmv_new_vs_churned,'')), 'ongoing') > 0
      then 'Ongoing'
    else null
  end as historical_smb_movement_type,

  case
    when coalesce(b.historical_bu,'SMB') = 'MM'
     and coalesce(b.current_bu,'SMB')    = 'SMB' then 'in'
    when coalesce(b.historical_bu,'SMB') = 'SMB'
     and coalesce(b.current_bu,'SMB')    = 'MM'  then 'out'
    when coalesce(b.historical_bu,'SMB') = 'SMB'
     and instr(lower(coalesce(c.gmv_new_vs_churned,'')), 'stopped selling') > 0
      then 'out'
    when coalesce(b.historical_bu,'SMB') = 'SMB'
     and instr(lower(coalesce(c.gmv_new_vs_churned,'')), 'started selling') > 0
     and instr(lower(coalesce(c.gmv_new_vs_churned,'')), 'stopped selling')  = 0
      then 'in'
    when coalesce(b.historical_bu,'SMB') = 'SMB'
     and instr(lower(coalesce(c.gmv_new_vs_churned,'')), 'ongoing') > 0
      then 'ongoing'
    else null
  end as historical_smb_in_out_movements

from cls c
left join bu b
  on b.store_id = c.store_id
 and b.mes      = c.mes