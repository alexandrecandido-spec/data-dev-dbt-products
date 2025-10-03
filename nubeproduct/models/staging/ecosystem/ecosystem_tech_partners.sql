{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['partner_id', 'country_code'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with partners as (
      select 
         p.id as partner_id
         ,p.name as partner_name
         ,p.email
         ,p.country
         ,mc.code as country_code
         ,phone_number
         ,website
         ,description
         ,date(created_at) as partner_creation_date
         ,LISTAGG(pt.type, ', ') within group (order by pt.type) as partner_type
      from {{ source('stg_ecosystem', 'mwp_partners') }} p
      left join {{ source('stg_ecosystem', 'mwp_partner_partner_types') }} pt
         on p.id = pt.partner_id
      left join {{ source('bronze_risk_ecosystem', 'mwp_countries') }} mc 
         on p.country = mc.id
      where true 
      and p.id not in (83)
      group by 1,2,3,4,5,6,7,8,9
)
SELECT 
    concat(p.partner_id, '_', p.country_code) as unique_partner_country_code
    ,p.*
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by 
FROM partners p
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1 
    FROM {{ this }} existing 
    WHERE existing.partner_id = p.partner_id 
    AND existing.country_code = p.country_code
)
{% endif %}