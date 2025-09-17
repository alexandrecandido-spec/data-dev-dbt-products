with base as (
  select store_id
  from {{ ref('company_metrics_merchant_info') }}
),

att as (
  select
    store_id,
    click_timestamp,
    -- clasificación MKT
    mkt_source        as team,
    mkt_subteam       as subteam,
    campaign,
    landing_page_domain,
    landing_page_path,
    register_url,
    -- negocio
    churned_at,
    first_seller_at,
    blocked_fraud_tag,
    partner_id,
    partner_code,
    partnership_type,
    -- flags
    trials_first_click,
    trials_last_click
  from {{ ref('marketing_attribution_model') }}
  where store_id in (select store_id from base)
),

-- Agregado por store_id max case
agg as (
  select
    store_id,

    -- teams / subteams renombrados con prefijo mkt_source_
    max(case when trials_first_click = 1 then team    end) as mkt_source_first_click,
    max(case when trials_first_click = 1 then subteam end) as mkt_subteam_first_click,
    max(case when trials_last_click  = 1 then team    end) as mkt_source_last_click,
    max(case when trials_last_click  = 1 then subteam end) as mkt_subteam_last_click,

    -- campañas y páginas con prefijo mkt_
    max(case when trials_first_click = 1 then campaign            end) as mkt_campaign_first_click,
    max(case when trials_last_click  = 1 then campaign            end) as mkt_campaign_last_click,

    max(case when trials_first_click = 1 then landing_page_domain end) as mkt_landing_page_domain_first_click,
    max(case when trials_last_click  = 1 then landing_page_domain end) as mkt_landing_page_domain_last_click,

    max(case when trials_first_click = 1 then landing_page_path   end) as mkt_landing_page_path_first_click,
    max(case when trials_last_click  = 1 then landing_page_path   end) as mkt_landing_page_path_last_click,

    max(case when trials_first_click = 1 then register_url        end) as mkt_register_url,

    -- negocio en el evento last-click
    max(case when trials_last_click = 1 then churned_at end) as churned_at,

    -- FRAUDE agregado (único campo, 0/1)
    max(
        case
            when lower(trim(cast(blocked_fraud_tag as string))) in ('1','true') then 1
            else 0
        end) as blocked_fraud_tag,

    -- primera vez seller a nivel tienda
    min(first_seller_at) as first_seller_at
  from att
  group by 1
),

-- Último partner NO nulo por tienda
partner_last_non_null as (
  select partner_id, partner_code, partnership_type, store_id
  from (
    select
      store_id, partner_id, partner_code, partnership_type,
      row_number() over (
        partition by store_id
        order by
          case when partner_id is not null or partner_code is not null or partnership_type is not null then 0 else 1 end,
          click_timestamp desc
      ) as rn
    from att
  ) x
  where rn = 1
)

select
  b.store_id,

  a.first_seller_at is not null as was_new_seller,
  a.first_seller_at,
  a.churned_at,

  -- renamed teams/subteams
  a.mkt_source_first_click,
  a.mkt_subteam_first_click,
  a.mkt_source_last_click,
  a.mkt_subteam_last_click,
  a.mkt_campaign_first_click,
  a.mkt_campaign_last_click,
  a.mkt_landing_page_domain_first_click,
  a.mkt_landing_page_domain_last_click,
  a.mkt_landing_page_path_first_click,
  a.mkt_landing_page_path_last_click,
  a.mkt_register_url,

  -- fraude único
  a.blocked_fraud_tag,

  -- partner
  p.partner_id,
  p.partner_code,
  p.partnership_type

from base b
left join agg a                   on b.store_id = a.store_id
left join partner_last_non_null p on b.store_id = p.store_id


