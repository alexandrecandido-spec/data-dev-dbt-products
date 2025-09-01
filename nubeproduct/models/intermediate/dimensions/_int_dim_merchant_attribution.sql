{{ config(materialized='view') }}

with base as (
  select store_id
  from {{ source('int_data_operations','company_metrics_merchant_info') }}
),

att as (
  select
    store_id,
    click_timestamp,
    first_seller_at,
    churned_at,
    mkt_source   as team,
    mkt_subteam  as subteam,
    blocked_fraud_tag,
    partner_id,
    partner_code,
    partnership_type
  from {{ source('int_marketing','marketing_attribution_model') }}
  where store_id in (select store_id from base)
),

first_row as (
  select *
  from (
    select a.*, row_number() over (partition by store_id order by click_timestamp asc) as rn_first
    from att a
  ) t
  where rn_first = 1
),

last_row as (
  select *
  from (
    select a.*, row_number() over (partition by store_id order by click_timestamp desc) as rn_last
    from att a
  ) t
  where rn_last = 1
),

-- normalizamos a entero 0/1 sin mezclar tipos
fraud as (
  select
    store_id,
    max(case
          when blocked_fraud_tag = 1 or blocked_fraud_tag = true then 1
          else 0
        end) as has_blocked_fraud
  from att
  group by 1
),

partner_last_non_null as (
  select partner_id, partner_code, partnership_type, store_id
  from (
    select
      store_id, partner_id, partner_code, partnership_type,
      row_number() over (
        partition by store_id
        order by (case when partner_id is not null or partner_code is not null or partnership_type is not null then 0 else 1 end),
                 click_timestamp desc
      ) as rn
    from att
  ) x
  where rn = 1
)

select
  b.store_id,

  (min(a.first_seller_at) is not null)            as was_new_seller,
  min(a.first_seller_at)                          as first_seller_at,

  lr.churned_at                                   as churned_at,

  fr.team                                         as first_team,
  fr.subteam                                      as first_subteam,
  lr.team                                         as last_team,
  lr.subteam                                      as last_subteam,

  -- boolean derivado desde entero 0/1
  (f.has_blocked_fraud = 1)                       as has_blocked_fraud,
  -- evita mezclar tipos (int/bool) en coalesce
  case when lr.blocked_fraud_tag = 1 or lr.blocked_fraud_tag = true then true else false end
                                                   as blocked_fraud_tag_latest,

  p.partner_id,
  p.partner_code,
  p.partnership_type

from base b
left join att a                   on b.store_id = a.store_id
left join first_row fr            on b.store_id = fr.store_id
left join last_row  lr            on b.store_id = lr.store_id
left join partner_last_non_null p on b.store_id = p.store_id
left join fraud f                 on b.store_id = f.store_id
group by
  b.store_id, lr.churned_at, fr.team, fr.subteam, lr.team, lr.subteam,
  f.has_blocked_fraud, lr.blocked_fraud_tag, p.partner_id, p.partner_code, p.partnership_type

