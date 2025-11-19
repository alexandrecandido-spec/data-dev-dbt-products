-- Calendario
with dates as (
  select
    date_id  as full_date,
    year_id  as year_number,
    month_id as month_number,
    day_name as day_name
  from {{ ref('dim_calendar') }}
  where date_id >= DATE '2024-01-01'
),

-- Attribution (SIN fraude acá)
attr as (
  select
    store_id,
    country_code as country,
    mkt_source,
    trials_mean_click
  from {{ ref('s__general__mkt_attribution_model__event') }}
),

-- Core (created_at)
store_core as (
  select
    store_id,
    cast(created_at as date) as store_created_date
  from {{ ref('s__attributes__store_core__ref') }}
),

-- Status (first_payment, first_seller, y flag bloqueado)
{% set status_rel = ref('s__lifecycle__store_status__ref') %}
{% if execute %}
  {% set status_cols = adapter.get_columns_in_relation(status_rel) %}
  {% set status_colnames = status_cols | map(attribute='name') | map('lower') | list %}
  {% set has_is_blocked_store  = 'is_blocked_store'  in status_colnames %}
  {% set has_is_store_blocked  = 'is_store_blocked'  in status_colnames %}
{% else %}
  {% set has_is_blocked_store  = true %}
  {% set has_is_store_blocked  = false %}
{% endif %}

store_status as (
  select
    store_id,
    cast(first_payment   as date) as first_payment_date,
    cast(first_seller_at as date) as first_seller_date,
    {% if has_is_blocked_store %}
      coalesce(cast(is_blocked_store as int), 0) as is_blocked_flag
    {% elif has_is_store_blocked %}
      coalesce(cast(is_store_blocked as int), 0) as is_blocked_flag
    {% else %}
      0 as is_blocked_flag
    {% endif %}
  from {{ status_rel }}
),

-- Unificación de eventos (excluye bloqueados)
events as (
  select
    a.store_id,
    a.country,
    a.mkt_source,
    a.trials_mean_click,
    sc.store_created_date,
    ss.first_payment_date,
    ss.first_seller_date
  from attr a
  inner join store_status ss
    on ss.store_id = a.store_id
   and coalesce(ss.is_blocked_flag, 0) = 0
  left  join store_core   sc
    on sc.store_id = a.store_id
  where coalesce(sc.store_created_date, ss.first_payment_date, ss.first_seller_date)
        >= {{ var('start_date', "DATE '2024-01-01'") }}
),

-- Universo país × fuente
combos as (
  select distinct country, mkt_source
  from events
),

grid as (
  select
    d.full_date, d.year_number, d.month_number, d.day_name,
    c.country, c.mkt_source
  from dates d
  cross join combos c
),

-- Buckets por fecha de cada métrica
trials as (
  select
    store_created_date as full_date,
    country,
    mkt_source,
    sum(trials_mean_click) as trials
  from events
  where store_created_date is not null
  group by 1,2,3
),

payments as (
  select
    first_payment_date as full_date,
    country,
    mkt_source,
    sum(trials_mean_click) as payments
  from events
  where first_payment_date is not null
  group by 1,2,3
),

new_sellers as (
  select
    first_seller_date as full_date,
    country,
    mkt_source,
    sum(trials_mean_click) as new_sellers
  from events
  where first_seller_date is not null
    and first_payment_date is not null
    and first_seller_date > first_payment_date
  group by 1,2,3
)

select
  g.full_date,
  g.year_number,
  g.month_number,
  g.day_name,
  g.country,
  g.mkt_source,
  -- Pasado/today con 0 si no hubo eventos; FUTURO = NULL
  case when g.full_date > current_date() then null else coalesce(t.trials,       0) end as effective_trials,
  case when g.full_date > current_date() then null else coalesce(p.payments,     0) end as effective_new_payments,
  case when g.full_date > current_date() then null else coalesce(ns.new_sellers, 0) end as effective_new_sellers
from grid g
left join trials      t  on (g.full_date, g.country, g.mkt_source) = (t.full_date, t.country, t.mkt_source)
left join payments    p  on (g.full_date, g.country, g.mkt_source) = (p.full_date, p.country, p.mkt_source)
left join new_sellers ns on (g.full_date, g.country, g.mkt_source) = (ns.full_date, ns.country, ns.mkt_source)