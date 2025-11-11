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
)

select
  b.store_id,
  b.mes,
  case
    -- 1. Started & Stopped Selling & Churned this month
    when fl.is_first_sale_month = 1 and fl.is_last_sale_month = 1
         and date_trunc('month', b.mes) = date_trunc('month', lc.churned_at)
      then 'Started & Stopped Selling & Churned this month'

    -- 2. Started & Stopped Selling & Churned later
    when fl.is_first_sale_month = 1 and fl.is_last_sale_month = 1
         and lc.churned_at is not null
         and date_trunc('month', lc.churned_at) > date_trunc('month', b.mes)
      then 'Started & Stopped Selling this month & Churned later'

    -- 3. Started & Stopped Selling (no es mes actual)
    when fl.is_first_sale_month = 1 and fl.is_last_sale_month = 1
         and (lc.churned_at is null or date_trunc('month', lc.churned_at) < date_trunc('month', b.mes))
         and date_trunc('month', b.mes) <> date_trunc('month', current_date)
      then 'Started & Stopped Selling this month'

    -- 4. Started Selling (solo si mes en curso)
    when fl.is_first_sale_month = 1
         and date_trunc('month', b.mes) = date_trunc('month', current_date)
      then 'Started Selling this month'

    -- 5. Started Selling (cuando no es también last_sale)
    when fl.is_first_sale_month = 1
      then 'Started Selling this month'

    -- 6. Ongoing (ambos flags en 0)
    when fl.is_first_sale_month = 0 and fl.is_last_sale_month = 0
      then 'Ongoing'

    -- 7. Stopped Selling & Churned this month
    when fl.is_last_sale_month = 1
         and date_trunc('month', b.mes) = date_trunc('month', lc.churned_at)
      then 'Stopped Selling & Churned this month'

    -- 8. Stopped Selling & Churned later
    when fl.is_last_sale_month = 1
         and lc.churned_at is not null
         and date_trunc('month', lc.churned_at) > date_trunc('month', b.mes)
      then 'Stopped Selling this month & Churned later'

    -- 9. Stopped Selling (no es mes actual)
    when fl.is_last_sale_month = 1
         and (lc.churned_at is null or date_trunc('month', lc.churned_at) < date_trunc('month', b.mes))
         and date_trunc('month', b.mes) <> date_trunc('month', current_date)
      then 'Stopped Selling this month'

    -- 10. Ongoing (último mes es el actual)
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