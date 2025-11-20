{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    unique_key           = ['full_date','country','mkt_source'],
    partition_by         = ['year_number','month_number'],
    cluster_by           = ['country','mkt_source'],
    on_schema_change     = 'fail',
    tags                 = ['daily-9am']         
) }}

{# columnas del payload a hashear (para detectar cambios) #}
{% set payload_cols = [
  'year_number','month_number','day_name',
  'effective_trials','effective_new_payments','effective_new_sellers',
  'forecast_trials','forecast_payments',
  'expected_monthly_trials','expected_monthly_new_payments','expected_monthly_new_sellers',
  'ponderation_key_trials','ponderation_key_payments','ponderation_key_new_sellers',
  'expected_daily_linear_trials','expected_daily_linear_new_payments','expected_daily_linear_new_sellers',
  'expected_daily_weighted_trials','expected_daily_weighted_new_payments','expected_daily_weighted_new_sellers'
] %}

-- Último día del último mes en el plan (define horizonte de forecast)
with plan_window as (
  select coalesce(
           max(last_day(to_date(
                 concat(cast(year  as string), '-',
                        lpad(cast(month as string), 2, '0'), '-01')
               ))),
           add_months(current_date(), 12)  -- fallback defensivo si el plan está vacío
         ) as plan_last_day
  from {{ source('data_manual','ext__marketing__acquisition__mkt_monthly_kpis_plan') }}
),

recalc_window as (
  select
    current_date()                        as today_,
    (select plan_last_day from plan_window) as window_end
),

-- Fuente consolidada (INT): effectives + budget + forecast
base as (
  select *
  from {{ ref('_int__acquisition__daily_dataproduct__agg_daily') }}
  where full_date >= DATE '2024-01-01'
    and full_date <= (select window_end from recalc_window)
    {% if is_incremental() %}
      and full_date > current_date()     -- freeze pasado cuando es incremental
    {% endif %}
),


-- Enmascara forecast FUTURO según disponibilidad de plan (el pasado queda siempre poblado)
masked as (
  select
    b.full_date, b.year_number, b.month_number, b.day_name,
    b.country, b.mkt_source,

    -- efectivos (tu INT ya pone NULL en futuro)
    b.effective_trials,
    b.effective_new_payments,
    b.effective_new_sellers,

    -- forecast: pasado/backcast siempre; futuro solo si hay plan de la métrica
    case
      when b.full_date > current_date() and b.expected_monthly_trials is null then null
      else b.forecast_trials
    end as forecast_trials,

    case
      when b.full_date > current_date() and b.expected_monthly_new_payments is null then null
      else b.forecast_payments
    end as forecast_payments,

    -- budget + distribuciones
    b.expected_monthly_trials,
    b.expected_monthly_new_payments,
    b.expected_monthly_new_sellers,
    b.ponderation_key_trials,
    b.ponderation_key_payments,
    b.ponderation_key_new_sellers,
    b.expected_daily_linear_trials,
    b.expected_daily_linear_new_payments,
    b.expected_daily_linear_new_sellers,
    b.expected_daily_weighted_trials,
    b.expected_daily_weighted_new_payments,
    b.expected_daily_weighted_new_sellers
  from base b
),

-- Snapshot de lo ya materializado (para preservar created_* y detectar cambios)
existing_data as (
  {{ get_existing_data(
      this,
      ['full_date','country','mkt_source','payload_hash','sys_audit_created_on','sys_audit_created_by']
  ) }}
),

-- Hash del payload enmascarado (null-safe)
final_payload as (
  select
    m.*,
    {{ marketing_mpt_hash(payload_cols) }} as payload_hash
  from masked m
),

-- Auditoría + diff contra target
joined as (
  select
    fp.*,
    coalesce(e.sys_audit_created_on, current_timestamp())     as sys_audit_created_on,
    coalesce(e.sys_audit_created_by, 'data-dev-dbt-products') as sys_audit_created_by,
    current_timestamp()                                       as sys_audit_updated_on,
    'data-dev-dbt-products'                                   as sys_audit_updated_by,
    e.payload_hash                                            as payload_hash_prev
  from final_payload fp
  left join existing_data e
    on  fp.full_date  = e.full_date
    and fp.country    = e.country
    and fp.mkt_source = e.mkt_source
)

-- Exposición final
select
  full_date, year_number, month_number, day_name,
  country, mkt_source,

  effective_trials, effective_new_payments, effective_new_sellers,
  forecast_trials,  forecast_payments,

  expected_monthly_trials, expected_monthly_new_payments, expected_monthly_new_sellers,
  ponderation_key_trials,  ponderation_key_payments,  ponderation_key_new_sellers,
  expected_daily_linear_trials,  expected_daily_linear_new_payments,  expected_daily_linear_new_sellers,
  expected_daily_weighted_trials, expected_daily_weighted_new_payments, expected_daily_weighted_new_sellers,

  payload_hash,
  sys_audit_created_on, sys_audit_created_by, sys_audit_updated_on, sys_audit_updated_by
from joined
where
  {% if is_incremental() %}
    -- upsert sólo cuando hay cambios en el contenido
    payload_hash_prev is null
    or payload_hash is distinct from payload_hash_prev
  {% else %}
    true
  {% endif %}
