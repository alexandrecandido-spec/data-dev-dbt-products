with base as (
  select
    store_id,
    country_code
  from {{ ref('company_metrics_merchant_info') }}
),

pd as (
  select
    store_id,
    partner_id,
    mkt_exclusion,
    partnership_type,
    affiliate_classification,
    partner_country_code
  from {{ ref('partners_agencies_affiliates_stores') }}
),

-- Flags por store (ya queda 1x store_id)
partner_flags as (
  select
    b.store_id,
    max(case
          when p.partner_id is not null
           and p.mkt_exclusion is null
           and p.partnership_type = 'store_development'
          then 1 else 0 end)                                       as has_partner_store_dev,

    max(case
          when p.partner_id is not null
           and p.mkt_exclusion is null
          then 1 else 0 end)                                       as has_affiliate,

    max(case
          when p.partner_id is not null
           and p.mkt_exclusion is null
           and p.affiliate_classification is not null
           and p.partner_country_code = b.country_code
          then 1 else 0 end)                                       as has_aff_class_local,

    max(case
          when p.partner_id is not null
           and p.mkt_exclusion is null
           and p.partner_country_code = b.country_code
          then p.affiliate_classification
        end)                                                       as affiliate_classification_local
  from base b
  left join pd p
    on b.store_id = p.store_id
  group by 1
),

-- QL profiles: colapsar a 1x store_id (evita fan-out)
ql_profiles as (
  select
    store_id,
    max(profile) as ql_profile        -- determinístico y simple
  from {{ source('int_data_predictors','marketing_new_payment_predictor_profiles') }}
  group by store_id
)

select
  b.store_id,

  case
    when pf.has_partner_store_dev = 1 then 'Partners'
    when pf.has_affiliate         = 1 then 'Affiliates'
    else 'Otros Teams'
  end as mkt_source_partner_click,

  case
    when pf.has_partner_store_dev = 1 then 'Partners'
    when pf.affiliate_classification_local is not null
      then pf.affiliate_classification_local
    when pf.has_affiliate = 1 then 'Long Tail'
    else 'Otros Teams'
  end as mkt_subteam_partner_click,

  qp.ql_profile

from base b
left join partner_flags pf on b.store_id = pf.store_id
left join ql_profiles  qp  on b.store_id = qp.store_id

