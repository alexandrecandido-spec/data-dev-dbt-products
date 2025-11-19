
-- INT: Daily Budget Distribution (linear & weighted) para trials, payments, new_sellers

with cal as (
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

plan as (
  select
    year, month, country, mkt_source,
    expected_monthly_trials,
    expected_monthly_new_payments,
    expected_monthly_new_sellers
  from {{ source('data_manual','ext__marketing__acquisition__mkt_monthly_kpis_plan') }}
),

-- Key dates con alias dinámico a special_day
{% set kd_rel = source('data_manual','ext__marketing__acquisition__key_dates_by_country') %}
{% if execute %}
  {% set kd_cols = adapter.get_columns_in_relation(kd_rel) %}
  {% set kd_names = kd_cols | map(attribute='name') | map('lower') | list %}
  {% set has_special_day  = 'special_day'  in kd_names %}
  {% set has_key_day      = 'key_day'      in kd_names %}
  {% set has_type_of_day  = 'type_of_day'  in kd_names %}
{% else %}
  {% set has_special_day  = true %}
  {% set has_key_day      = false %}
  {% set has_type_of_day  = false %}
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

eff as (
  select
    full_date, country, mkt_source,
    effective_trials, effective_new_payments, effective_new_sellers
  from {{ ref('_int__acquisition__daily_kpis_mean_click') }}
),

eff_with_tod as (
  select
    e.full_date, e.country, e.mkt_source,
    coalesce(k.special_day, c.day_name) as type_of_day,
    e.effective_trials, e.effective_new_payments, e.effective_new_sellers
  from eff e
  join cal c on c.full_date = e.full_date
  left join key_dates k on k.full_date = e.full_date and k.country = e.country
),

weights_15m as (
  select
    full_date, country, mkt_source, type_of_day,
    avg(effective_trials)       over (
      partition by country, mkt_source, type_of_day
      order by full_date
      RANGE BETWEEN INTERVAL 15 MONTHS PRECEDING AND CURRENT ROW
    ) as avg_trials_last_15m_type_day,
    avg(effective_new_payments) over (
      partition by country, mkt_source, type_of_day
      order by full_date
      RANGE BETWEEN INTERVAL 15 MONTHS PRECEDING AND CURRENT ROW
    ) as avg_payments_last_15m_type_day,
    avg(effective_new_sellers)  over (
      partition by country, mkt_source, type_of_day
      order by full_date
      RANGE BETWEEN INTERVAL 15 MONTHS PRECEDING AND CURRENT ROW
    ) as avg_new_sellers_last_15m_type_day
  from eff_with_tod
),

plan_calendar as (
  select
    c.full_date, c.year_number, c.month_number, c.day_name, c.month_start, c.month_end,
    p.country, p.mkt_source,
    p.expected_monthly_trials, p.expected_monthly_new_payments, p.expected_monthly_new_sellers
  from cal c
  join plan p
    on p.year = c.year_number and p.month = c.month_number
),

base as (
  select
    pc.*,
    kd.special_day,
    coalesce(kd.special_day, pc.day_name) as type_of_day,
    w.avg_trials_last_15m_type_day,
    w.avg_payments_last_15m_type_day,
    w.avg_new_sellers_last_15m_type_day
  from plan_calendar pc
  left join key_dates kd
    on kd.full_date = pc.full_date and kd.country = pc.country
  left join weights_15m w
    on (w.full_date, w.country, w.mkt_source, w.type_of_day)
     = (pc.full_date, pc.country, pc.mkt_source, coalesce(kd.special_day, pc.day_name))
),

scored as (
  select
    b.*,
    sum(avg_trials_last_15m_type_day)      over (partition by country, mkt_source, year_number, month_number) as sum_avg_trials_m,
    sum(avg_payments_last_15m_type_day)    over (partition by country, mkt_source, year_number, month_number) as sum_avg_payments_m,
    sum(avg_new_sellers_last_15m_type_day) over (partition by country, mkt_source, year_number, month_number) as sum_avg_new_sellers_m
  from base b
)

select
  full_date, year_number, month_number, day_name, country, mkt_source,
  expected_monthly_trials, expected_monthly_new_payments, expected_monthly_new_sellers,

  case when avg_trials_last_15m_type_day      is not null and sum_avg_trials_m       > 0
       then avg_trials_last_15m_type_day      / sum_avg_trials_m end as ponderation_key_trials,
  case when avg_payments_last_15m_type_day    is not null and sum_avg_payments_m     > 0
       then avg_payments_last_15m_type_day    / sum_avg_payments_m end as ponderation_key_payments,
  case when avg_new_sellers_last_15m_type_day is not null and sum_avg_new_sellers_m  > 0
       then avg_new_sellers_last_15m_type_day / sum_avg_new_sellers_m end as ponderation_key_new_sellers,

  case when expected_monthly_trials            is not null and sum_avg_trials_m       > 0
       then expected_monthly_trials            * (avg_trials_last_15m_type_day      / sum_avg_trials_m) end as expected_daily_weighted_trials,
  case when expected_monthly_new_payments      is not null and sum_avg_payments_m     > 0
       then expected_monthly_new_payments      * (avg_payments_last_15m_type_day    / sum_avg_payments_m) end as expected_daily_weighted_new_payments,
  case when expected_monthly_new_sellers       is not null and sum_avg_new_sellers_m  > 0
       then expected_monthly_new_sellers       * (avg_new_sellers_last_15m_type_day / sum_avg_new_sellers_m) end as expected_daily_weighted_new_sellers,

  case when expected_monthly_trials            is not null
       then expected_monthly_trials            / dayofmonth(month_end) end as expected_daily_linear_trials,
  case when expected_monthly_new_payments      is not null
       then expected_monthly_new_payments      / dayofmonth(month_end) end as expected_daily_linear_new_payments,
  case when expected_monthly_new_sellers       is not null
       then expected_monthly_new_sellers       / dayofmonth(month_end) end as expected_daily_linear_new_sellers
from scored
order by full_date, country, mkt_source
