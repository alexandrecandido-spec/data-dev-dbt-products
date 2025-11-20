
-- Forecast (past & future) ANCLADO:
-- * Trials: promedio de últimos 90 días hasta anchor_trials(D)
-- * Payments: promedio de últimos 180 días (holiday) / 90 días (no-holiday) hasta anchor_payments(D)
-- * anchor_metric(D) = LEAST(D-1, last_effective_metric_date)
-- * Fallbacks: 180 sin filtro -> 365 sin filtro -> 0
-- * Nunca usamos forecasts como insumo; solo efectivos históricos

with base_dates as (
  select
    date_id            as full_date,
    year_id            as year_number,
    month_id           as month_number,
    day_name           as day_name,
    first_day_of_month as month_start,
    last_day_of_month  as month_end
  from {{ ref('dim_calendar') }}
  where date_id >= DATE '2024-01-01'
),

combos as (
  select distinct country, mkt_source
  from {{ ref('_int__acquisition__daily_kpis_mean_click') }}
),

grid as (
  select
    d.full_date, d.year_number, d.month_number, d.day_name, d.month_start, d.month_end,
    c.country, c.mkt_source
  from base_dates d
  cross join combos c
),

-- Key dates -> mapear a 'special_day' de forma dinámica
{% set kd_rel = source('data_manual','ext__marketing__acquisition__key_dates_by_country') %}
{% if execute %}
  {% set kd_cols  = adapter.get_columns_in_relation(kd_rel) %}
  {% set kd_names = kd_cols | map(attribute='name') | map('lower') | list %}
  {% set has_special_day = 'special_day'  in kd_names %}
  {% set has_key_day     = 'key_day'      in kd_names %}
  {% set has_type_of_day = 'type_of_day'  in kd_names %}
{% else %}
  {% set has_special_day = true %}
  {% set has_key_day     = false %}
  {% set has_type_of_day = false %}
{% endif %}

key_dates as (
  select
    cast(date as date) as full_date,
    country,
    {% if has_special_day %} special_day
    {% elif has_key_day %}   key_day       as special_day
    {% elif has_type_of_day %} type_of_day as special_day
    {% else %}               cast(null as string) as special_day
    {% endif %}
  from {{ kd_rel }}
),

g as (
  select
    gr.*,
    kd.special_day,
    coalesce(kd.special_day, gr.day_name) as type_of_day
  from grid gr
  left join key_dates kd
    on kd.full_date = gr.full_date
   and kd.country   = gr.country
),

eff as (
  select
    full_date,
    country,
    mkt_source,
    effective_trials,        -- sin coalesce para no contaminar promedios
    effective_new_payments   -- sin coalesce
  from {{ ref('_int__acquisition__daily_kpis_mean_click') }}
),

-- última fecha con efectivos por métrica (por combo)
last_eff as (
  select
    country,
    mkt_source,
    max(case when effective_trials        is not null then full_date end) as last_eff_trials_date,
    max(case when effective_new_payments  is not null then full_date end) as last_eff_payments_date
  from eff
  group by 1,2
),

-- anclas por fila (nunca anclar en futuro)
anchored as (
  select
    g.*,
    le.last_eff_trials_date,
    le.last_eff_payments_date,
    least(coalesce(le.last_eff_trials_date,   current_date()), date_add(g.full_date, -1)) as anchor_trials_date,
    least(coalesce(le.last_eff_payments_date, current_date()), date_add(g.full_date, -1)) as anchor_payments_date
  from g
  left join last_eff le
    on (g.country, g.mkt_source) = (le.country, le.mkt_source)
)

select
  a.full_date, a.year_number, a.month_number, a.day_name, a.month_start, a.month_end,
  a.country, a.mkt_source, a.special_day, a.type_of_day,

  -- TRIALS: target no-holiday => 90d no-holiday; fallbacks 180/365 sin filtro; 0
  coalesce(
    case when a.special_day is null then (
      select avg(e2.effective_trials)
      from eff e2
      left join key_dates kd2
        on kd2.country = a.country and kd2.full_date = e2.full_date
      where e2.country = a.country
        and e2.mkt_source = a.mkt_source
        and e2.full_date between date_add(a.anchor_trials_date, -90) and a.anchor_trials_date
        and kd2.special_day is null
        and e2.effective_trials is not null
    ) end,
    ( select avg(e2.effective_trials)
      from eff e2
      where e2.country = a.country
        and e2.mkt_source = a.mkt_source
        and e2.full_date between date_add(a.anchor_trials_date, -180) and a.anchor_trials_date
        and e2.effective_trials is not null
    ),
    ( select avg(e2.effective_trials)
      from eff e2
      where e2.country = a.country
        and e2.mkt_source = a.mkt_source
        and e2.full_date between date_add(a.anchor_trials_date, -365) and a.anchor_trials_date
        and e2.effective_trials is not null
    ),
    0.0
  ) as forecast_trials,

  -- PAYMENTS: target holiday => 180d holiday; fallbacks 180/365 sin filtro; 0
  coalesce(
    case when a.special_day is not null then (
      select avg(e2.effective_new_payments)
      from eff e2
      left join key_dates kd2
        on kd2.country = a.country and kd2.full_date = e2.full_date
      where e2.country = a.country
        and e2.mkt_source = a.mkt_source
        and e2.full_date between date_add(a.anchor_payments_date, -180) and a.anchor_payments_date
        and kd2.special_day is not null
        and e2.effective_new_payments is not null
    ) end,
    ( select avg(e2.effective_new_payments)
      from eff e2
      where e2.country = a.country
        and e2.mkt_source = a.mkt_source
        and e2.full_date between date_add(a.anchor_payments_date, -180) and a.anchor_payments_date
        and e2.effective_new_payments is not null
    ),
    ( select avg(e2.effective_new_payments)
      from eff e2
      where e2.country = a.country
        and e2.mkt_source = a.mkt_source
        and e2.full_date between date_add(a.anchor_payments_date, -365) and a.anchor_payments_date
        and e2.effective_new_payments is not null
    ),
    0.0
  ) as forecast_payments

from anchored a