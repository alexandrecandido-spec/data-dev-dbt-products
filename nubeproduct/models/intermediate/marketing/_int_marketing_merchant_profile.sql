{{ config(materialized='ephemeral') }}

with base as (
  select store_id
  from {{ ref('company_metrics_merchant_info') }}
),

-- store_name desde i18n (última versión)
latest_name as (
  select store_id, nullif(trim(name), '') as store_name
  from (
    select
      ss.store_id,
      i18n.name,
      row_number() over (partition by ss.store_id order by i18n.id desc) as rnk
    from {{ source('int_moltres','mwp_store_settings') }} ss
    left join {{ source('int_moltres','mwp_store_settings_i18n') }} i18n
      on ss.id = i18n.store_setting_id
  ) t
  where rnk = 1
),

-- mejor candidato de doc desde invoice_info
merchant_id as (
  select
    m.store_id,
    upper(trim(m.id_type)) as id_type,
    trim(m.id_number)      as id_number,
    row_number() over (
      partition by m.store_id
      order by case upper(trim(m.id_type))
                 when 'CNPJ' then 0 when 'CPF' then 0 when 'CUIT' then 0
                 when 'RUT'  then 0 when 'RFC' then 0 when 'DNI'  then 0
                 else 9 end,
               m.name asc
    ) as rn
  from {{ source('int_moltres','mwp_invoice_info') }} m
),

-- fallback: business_id si no hay invoice_info
biz as (
  select
    ss.store_id,
    trim(ss.business_id) as business_id
  from {{ source('int_moltres','mwp_store_settings') }} ss
),

docs as (
  select
    b.store_id,
    case
      when mi.id_type in ('CNPJ','CPF','CUIT','RUT','RFC','DNI') then mi.id_type
      when bz.business_id is not null then 'UNKNOWN'
      else null
    end as doc_type,
    nullif(
      case
        when mi.id_type in ('CNPJ','CPF','CUIT','RUT','RFC','DNI')
          then regexp_replace(mi.id_number, '[^0-9A-Z]', '')
        else regexp_replace(bz.business_id, '[^0-9A-Z]', '')
      end
    , '') as doc_number
  from base b
  left join (select * from merchant_id where rn = 1) mi on b.store_id = mi.store_id
  left join biz bz on b.store_id = bz.store_id
)


select
  b.store_id,
  n.store_name,
  d.doc_type,
  d.doc_number
from base b
left join latest_name n on b.store_id = n.store_id
left join docs        d on b.store_id = d.store_id
