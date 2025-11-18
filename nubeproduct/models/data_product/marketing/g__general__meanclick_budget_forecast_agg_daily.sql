{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    unique_key           = ['full_date','country','mkt_source'],
    partition_by         = ['year_number','month_number'],
    cluster_by           = ['country','mkt_source'],
    on_schema_change     = 'fail',
    tags                 = ['daily-9am','marketing']
) }}

{% set start_date            = var('start_date', "'2024-01-01'") %}
{% set forecast_horizon_days = var('forecast_horizon_days', 420) %}
{% set force_backfill_from   = var('force_backfill_from', none) %}

-- columnas del payload para hash
{% set payload_cols = [
  'year_number','month_number','day_name',
  'effective_trials','effective_new_payments','effective_new_sellers',
  'forecast_trials','forecast_payments',
  'expected_monthly_trials','expected_monthly_new_payments','expected_monthly_new_sellers',
  'ponderation_key_trials','ponderation_key_payments','ponderation_key_new_sellers',
  'expected_daily_linear_trials','expected_daily_linear_new_payments','expected_daily_linear_new_sellers',
  'expected_daily_weighted_trials','expected_daily_weighted_new_payments','expected_daily_weighted_new_sellers'
] %}

with recalc_window as (
  select
    current_date()                                        as today_,
    date_add(current_date(), {{ forecast_horizon_days }}) as window_end
),

base as (
  select *
  from {{ ref('_int__acquisition__daily_dataproduct__agg_daily') }}
  {% if is_incremental() %}
    where
      (
        {% if force_backfill_from %}
          full_date >= {{ force_backfill_from }}
        {% else %}
          full_date > current_date()     -- FREEZE: el pasado no se recalcula
        {% endif %}
      )
      and full_date <= (select window_end from recalc_window)
  {% else %}
    where full_date >= {{ start_date }}
  {% endif %}
),

-- Enmascarar forecast FUTURO según disponibilidad de budget (métrica-específico)
masked as (
  select
    b.full_date, b.year_number, b.month_number, b.day_name,
    b.country, b.mkt_source,

    -- efectivos (tu INT ya los pone NULL en futuro)
    b.effective_trials,
    b.effective_new_payments,
    b.effective_new_sellers,

    -- forecast: pasado siempre poblado; FUTURO solo si hay plan mensual para la métrica
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

-- snapshot de lo ya materializado para preservar created_*
existing_data as (
  {{ get_existing_data(
      this,
      ['full_date','country','mkt_source','payload_hash','sys_audit_created_on','sys_audit_created_by']
  ) }}
),

final_payload as (
  select
    m.*,
    {{ marketing_mpt_hash(payload_cols) }} as payload_hash
  from masked m
),

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

select
  full_date, year_number, month_number, day_name, country, mkt_source,
  effective_trials, effective_new_payments, effective_new_sellers,
  forecast_trials, forecast_payments,
  expected_monthly_trials, expected_monthly_new_payments, expected_monthly_new_sellers,
  ponderation_key_trials, ponderation_key_payments, ponderation_key_new_sellers,
  expected_daily_linear_trials, expected_daily_linear_new_payments, expected_daily_linear_new_sellers,
  expected_daily_weighted_trials, expected_daily_weighted_new_payments, expected_daily_weighted_new_sellers,
  payload_hash,
  sys_audit_created_on, sys_audit_created_by, sys_audit_updated_on, sys_audit_updated_by
from joined
where
  {% if is_incremental() %}
    payload_hash_prev is null
    or payload_hash is distinct from payload_hash_prev
  {% else %}
    true
  {% endif %}
