{{ config(
  materialized='incremental',
  incremental_strategy='merge',
  unique_key=['date','full_url','path','search_type'],
  on_schema_change='fail',
  tags=['daily-6am','marketing']
) }}
  with 
  -- Patrones
  --INTERMEDIATE 1: route_patterns
  route_patterns as (
    select * from (values
      ('/blog'), ('/banners'), ('/e-books'), ('/ebooks'), ('/recursos'),
      ('/materiais'), ('/ferramentas'), ('/herramientas'), ('/trilhas'),
      ('/cursos-ecommerce'), ('/ecommerce-por-expertos'), ('/universidade'), ('/universidad')
    ) as t(pattern)
  ),
  --INTERMEDIATE 2: domain_patterns
  domain_patterns as (
    select * from (values
      ('creadordebanners.com'), ('creadordelogos.com.ar'), ('creadordelogos.com.mx'),
      ('criadordebanner.com'), ('criadordelogo.com.br'), ('fornecedoresdropshipping.com'),
      ('nuv.link'), ('paletadecolores.com.ar'), ('paletadecolores.com.mx'),
      ('paletadecores.com'), ('materiais.nuvemshop.com.br'), ('recursos.tiendanube.com'),
      ('trilhas.nuvemshop.com.br')
    ) as t(domain)
  ),

  -- Datos originales con device y country
  orig as (
    select
      cast(o.date as date) as date,
      o.full_url,
      o.path,
      o.search_type,
      o.country_name,
      o.device,
      sum(o.impressions) as orig_impr,
      sum(o.clicks) as orig_clicks,
      avg(o.average_position) as orig_pos
    from {{ ref('gsc__url_results') }} o
    left join route_patterns rp on instr(o.full_url, rp.pattern) > 0
    left join domain_patterns dp on startswith(o.full_url, 'https://www.' || dp.domain)
                                or startswith(o.full_url, 'https://' || dp.domain)
    where rp.pattern is not null or dp.domain is not null
    group by 1,2,3,4,5,6
  ),

  -- Agregado sin device y country para el join
  orig_base as (
    select
      cast(o.date as date) as date,
      o.full_url,
      o.path,
      o.search_type,
      sum(o.impressions) as orig_impr,
      sum(o.clicks) as orig_clicks,
      avg(o.average_position) as orig_pos
    from {{ ref('gsc__url_results') }} o
    left join route_patterns rp on instr(o.full_url, rp.pattern) > 0
    left join domain_patterns dp on startswith(o.full_url, 'https://www.' || dp.domain)
                                or startswith(o.full_url, 'https://' || dp.domain)
    where rp.pattern is not null or dp.domain is not null
    group by 1,2,3,4
  ),

  -- Unsplit data
  unsplit as (
    select
      u.date,
      u.full_url,
      u.path,
      u.search_type,
      sum(u.impressions) as unsplit_impr,
      sum(u.clicks) as unsplit_clicks,
      avg(u.position) as unsplit_pos
    from {{ ref('gsc__url_unsplit_results') }} u
    left join route_patterns rp on instr(u.full_url, rp.pattern) > 0
    left join domain_patterns dp on startswith(u.full_url, 'https://www.' || dp.domain)
                                or startswith(u.full_url, 'https://' || dp.domain)
    where rp.pattern is not null or dp.domain is not null
    group by 1,2,3,4
  ),

  -- Diferencias
  diffs as (
    select
      u.date,
      u.full_url,
      u.path,
      u.search_type,
      'Not Informed' as country_name,
      'Not Informed' as device,
      greatest(u.unsplit_impr - coalesce(o.orig_impr, 0), 0) as impressions,
      greatest(u.unsplit_clicks - coalesce(o.orig_clicks, 0), 0) as clicks,
      round(u.unsplit_pos, 2) as average_position
    from unsplit u
    left join orig_base o
      on u.date = o.date and u.full_url = o.full_url and u.path = o.path and u.search_type = o.search_type
    where 
      (coalesce(u.unsplit_impr, 0) - coalesce(o.orig_impr, 0) > 0)
      or (coalesce(u.unsplit_clicks, 0) - coalesce(o.orig_clicks, 0) > 0)
  ),

  -- Original limpio
  original_clean as (
    select
      date,
      full_url,
      path,
      search_type,
      country_name,
      device,
      orig_impr as impressions,
      orig_clicks as clicks,
      round(orig_pos, 2) as average_position
    from orig
  ),

  -- Unión
  final as (
    select * from original_clean
    union all
    select * from diffs
  )

  -- SELECT final con subteam y classified_country completos
  select
    *,
    case
      when instr(full_url, '/blog') > 0 then 'Blog'
      when instr(full_url, '/banners') > 0
        or instr(full_url, '/e-books') > 0
        or instr(full_url, '/ebooks') > 0
        or instr(full_url, '/recursos') > 0
        or instr(full_url, '/materiais') > 0
        or instr(full_url, 'materiais.nuvemshop.com.br') > 0
        or instr(full_url, 'recursos.tiendanube.com') > 0
        then 'Downloadables'
      when instr(full_url, '/ferramentas') > 0
        or instr(full_url, '/herramientas') > 0
        or instr(full_url, 'creadordebanners.com') > 0
        or instr(full_url, 'creadordelogos.com.ar') > 0
        or instr(full_url, 'creadordelogos.com.mx') > 0
        or instr(full_url, 'criadordebanner.com') > 0
        or instr(full_url, 'criadordelogo.com.br') > 0
        or instr(full_url, 'fornecedoresdropshipping.com') > 0
        or instr(full_url, 'nuv.link') > 0
        or instr(full_url, 'paletadecolores.com.ar') > 0
        or instr(full_url, 'paletadecolores.com.mx') > 0
        or instr(full_url, 'paletadecores.com') > 0
        then 'Tools'
      when instr(full_url, 'trilhas.nuvemshop.com.br') > 0
        or instr(full_url, '/trilhas') > 0
        or instr(full_url, '/cursos-ecommerce') > 0
        or instr(full_url, '/ecommerce-por-expertos') > 0
        or instr(full_url, '/universidade') > 0
        then 'Trilhas'
      when instr(full_url, '/universidad') > 0 then 'Universidad'
      else 'Otros'
    end as subteam,

    case
      when instr(full_url, 'nuvemshop') > 0
        or instr(full_url, '.br') > 0
        or instr(full_url, 'fornecedoresdropshipping.com') > 0
        or instr(full_url, 'nuv.link') > 0
        then 'BR'
      else
        case
          when date <= date '2024-09-07' then
            case
              when instr(full_url, '/mx/') > 0 then 'MX'
              when instr(full_url, '/co/') > 0 then 'CO'
              when instr(full_url, '/cl/') > 0 then 'CL'
              else 'AR'
            end
          else
            case
              when country_name like '%Mexico%' then 'MX'
              when country_name like '%Colombia%' then 'CO'
              when country_name like '%Chile%' then 'CL'
              when country_name like '%Argentina%' then 'AR'
              else 'Otros'
            end
        end
    end as classified_country

  from final
    {% if is_incremental() %}
        WHERE sys_audit_updated_on >= (SELECT COALESCE(MAX(sys_audit_updated_on), TIMESTAMP '1900-01-01') FROM {{ this }})
    {% endif %}