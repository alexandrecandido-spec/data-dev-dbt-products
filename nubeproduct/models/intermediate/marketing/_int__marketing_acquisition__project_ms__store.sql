-- Intermediate EPHEMERAL | Project Merchant Sellers (store grain)
-- Trae todo lo de staging + store core + lifecycle + attribution
-- Calcula lógica de tag (sin materializar) y auditorías por dependencia.

with ms_src as (  -- staging con 1..N filas por store
  select
    cast(store_id as bigint)                  as store_id,
    domain, emails, phones, instagram_url,
    platform, estimated_monthly_sales, peso, repeated_domain,
    disparos,
    cast(disparo_date as date)                as disparo_date,
    mapping_method,
    cast(sys_audit_updated_on as timestamp)   as ms_row_updated_on
  from {{ ref('marketing__acquisition__project_ms_base__domain') }}
  where store_id is not null
),

ms_rank as (  -- fila representativa por store
  select
    m.*,
    row_number() over (
      partition by m.store_id
      order by
        case when m.disparo_date is not null then 0 else 1 end,
        m.disparo_date asc,
        case m.mapping_method when 'domain_exact' then 0 when 'domain_clean' then 1 else 2 end,
        m.domain asc
    ) as rn,
    min(m.disparo_date) over (partition by m.store_id)      as first_disparo_date,
    max(m.ms_row_updated_on) over (partition by m.store_id) as deps_ms_updated_on
  from ms_src m
),

ms_store as (
  select
    store_id,
    domain, emails, phones, instagram_url,
    platform, estimated_monthly_sales, peso, repeated_domain,
    disparos, disparo_date, mapping_method,
    first_disparo_date,
    deps_ms_updated_on
  from ms_rank
  where rn = 1
),

store_core as (
  select
    cast(store_id as bigint)                 as store_id,
    cast(created_at as timestamp)            as created_at_ts,   
    cast(created_at as date)                 as created_at,      
    partner_code,
    cast(sys_audit_updated_on as timestamp)  as deps_sc_updated_on
  from {{ ref('s__attributes__store_core__ref') }}
),

lifecycle as (
  select
    cast(store_id as bigint)                           as store_id,
    case when new_seller = 1 then cast(first_seller_at as date) end as new_seller_at,
    cast(first_payment   as date)                      as first_payment,
    cast(churned_at      as date)                      as churned_at,
    cast(sys_audit_updated_on as timestamp)            as deps_lc_updated_on
  from {{ ref('s__lifecycle__store_status__ref') }}
),

visits as (  -- primera visita a /empreendedores/crescer%
  select
    cast(store_id as bigint)                 as store_id,
    min(cast(click_timestamp as timestamp))  as first_visit_ts,
    cast(min(cast(click_timestamp as timestamp)) as date) as first_visit_date,
    max(cast(sys_audit_updated_on as timestamp)) as deps_at_updated_on
  from {{ ref('marketing_attribution_model') }}
  where lower(landing_page_domain) = 'www.nuvemshop.com.br'
    and coalesce(lower(landing_page_path),'') like '/empreendedores/crescer%'
  group by 1
),

joined as ( 
  select
    sc.store_id,
    sc.created_at_ts,
    sc.created_at,
    sc.partner_code,

    v.first_visit_ts,
    v.first_visit_date,

    lc.new_seller_at,
    lc.first_payment,
    lc.churned_at,

    ms.domain, ms.emails, ms.phones, ms.instagram_url,
    ms.platform, ms.estimated_monthly_sales, ms.peso, ms.repeated_domain,
    ms.disparos, ms.disparo_date, ms.mapping_method,
    ms.first_disparo_date,

    ms.deps_ms_updated_on,
    sc.deps_sc_updated_on,
    lc.deps_lc_updated_on,
    v.deps_at_updated_on
  from store_core sc
  left join ms_store  ms on ms.store_id = sc.store_id         
  left join lifecycle lc on lc.store_id = sc.store_id
  left join visits    v  on v.store_id  = sc.store_id
),

logic as (  -- condiciones A y B
  select
    j.*,
    case
      when j.first_visit_ts is not null and j.created_at_ts is not null
       and j.first_visit_ts < j.created_at_ts
      then 1 else 0 end as cond_pre_creation_visit,          
    case
      when j.first_disparo_date is not null and j.created_at is not null
       and j.created_at > j.first_disparo_date
      then 1 else 0 end as cond_external_disparo            
  from joined j
),

decision as (  -- tag + reason + fecha de contacto
  select
    l.*,
    case
      when l.cond_external_disparo = 1 or l.cond_pre_creation_visit = 1 then 1
      else 0
    end as has_ms_tag,
    case
      when l.cond_external_disparo = 1 and l.cond_pre_creation_visit = 1 then 'both'
      when l.cond_external_disparo = 1 then 'external_disparo'
      when l.cond_pre_creation_visit = 1 then 'pre_creation_visit'
      else null
    end as ms_reason,
    case
      when l.cond_external_disparo = 1 then l.first_disparo_date
      when l.cond_pre_creation_visit = 1 then l.first_visit_date
      else null
    end as ms_contact_date
  from logic l
)

-- SALIDA: solo stores con tag (has_ms_tag = 1)
select
  store_id,
  has_ms_tag,
  ms_reason,
  ms_contact_date,

  -- core & lifecycle
  created_at,
  partner_code,
  new_seller_at,
  first_payment,
  churned_at,

  -- staging “representativa” + agregados (se preservan para el DP)
  domain, emails, phones, instagram_url,
  platform, estimated_monthly_sales, peso, repeated_domain,
  disparos, disparo_date, mapping_method,
  first_disparo_date,

  -- visitas
  first_visit_ts,
  first_visit_date,

  -- auditorías para incrementalidad downstream
  deps_ms_updated_on,
  deps_sc_updated_on,
  deps_lc_updated_on,
  deps_at_updated_on
from decision
where has_ms_tag = 1
