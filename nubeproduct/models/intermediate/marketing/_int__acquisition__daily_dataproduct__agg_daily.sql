{{ config(materialized='ephemeral') }}

with
eff as (select * from {{ ref('_int__acquisition__daily_kpis_mean_click') }}),
bdg as (select * from {{ ref('_int__acquisition__daily_budget_mean_click') }}),
fc  as (select * from {{ ref('_int__acquisition__daily_forecast_mean_click') }})

select
  coalesce(eff.full_date, bdg.full_date, fc.full_date)  as full_date,
  coalesce(eff.country,   bdg.country,   fc.country)    as country,
  coalesce(eff.mkt_source,bdg.mkt_source,fc.mkt_source) as mkt_source,

  coalesce(eff.year_number, bdg.year_number, fc.year_number)   as year_number,
  coalesce(eff.month_number,bdg.month_number,fc.month_number)  as month_number,
  coalesce(eff.day_name,    bdg.day_name,    fc.day_name)      as day_name,

  -- Effectives
  eff.effective_trials,
  eff.effective_new_payments,
  eff.effective_new_sellers,

  -- Forecast (trials & payments)
  fc.forecast_trials,
  fc.forecast_payments,

  -- Budget (plan + distribuciones)
  bdg.expected_monthly_trials,
  bdg.expected_monthly_new_payments,
  bdg.expected_monthly_new_sellers,
  bdg.ponderation_key_trials,
  bdg.ponderation_key_payments,
  bdg.ponderation_key_new_sellers,
  bdg.expected_daily_linear_trials,
  bdg.expected_daily_linear_new_payments,
  bdg.expected_daily_linear_new_sellers,
  bdg.expected_daily_weighted_trials,
  bdg.expected_daily_weighted_new_payments,
  bdg.expected_daily_weighted_new_sellers
from eff
full join bdg using (full_date, country, mkt_source)
full join fc  using (full_date, country, mkt_source)