{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['app_id', 'country_code'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

apps as (
      select
         a.id as app_id
         ,partners_id as partner_id
         ,handle as app_name
         ,ac.name as app_category
         ,date(a.created_at) as app_cretion_date
         ,date(published_at) as app_published_date
         ,date(a.deleted_at) as app_deleted_date
         ,date(date_trunc('month', a.created_at)) as month_creation_date
         ,LISTAGG(mc.code , ', ') within group (order by mac.country_id) as app_published_countries
      from {{ source('stg_ecosystem', 'apps') }} a
      left join {{ source('stg_ecosystem', 'apps_categories') }} ac
         on a.categories_id = ac.id
      left join (select distinct app_id, country_id from {{ source('stg_ecosystem', 'apps_countries') }} ) mac 
         on mac.app_id = a.id
      left join {{ source('bronze_risk_ecosystem', 'mwp_countries') }} mc 
         on mac.country_id = mc.id
      where a.deleted_at is null
      group by 1,2,3,4,5,6,7,8
)
SELECT 
    concat(a.app_id, '_', p.country_code) as unique_partner_country_code
    ,a.*
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by 
FROM apps a
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1 
    FROM {{ this }} existing 
    WHERE existing.partner_id = p.partner_id 
    AND existing.country_code = p.country_code
)
{% endif %}