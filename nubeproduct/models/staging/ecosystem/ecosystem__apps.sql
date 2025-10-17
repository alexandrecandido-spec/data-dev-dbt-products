{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['app_id', 'app_published_country'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with
apps as (
      select
         a.id as app_id
         ,partners_id as partner_id
         ,handle as app_name
         ,ac.name as app_category
         ,date(a.created_at) as app_creation_date
         ,date(published_at) as app_published_date
         ,date(a.deleted_at) as app_deleted_date
         ,date(date_trunc('month', a.created_at)) as month_creation_date
         ,case when published_at is not null then true else false end as is_app_published
         ,mc.code as app_published_country
      from {{ source('stg_ecosystem', 'apps') }} a
      left join {{ source('stg_ecosystem', 'apps_categories') }} ac
         on a.categories_id = ac.id
      left join (select distinct app_id, country_id from {{ source('stg_ecosystem', 'apps_countries') }} ) mac 
         on mac.app_id = a.id
      left join {{ source('stg_ecosystem', 'countries') }} mc 
         on mac.country_id = mc.id
      where a.deleted_at is null
)
SELECT 
    concat(a.app_id, '_', a.app_published_country) as unique_app_country_code
    ,a.*
    ,current_timestamp AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
    ,current_timestamp AS sys_audit_updated_on
    ,'data-dev-dbt-products' AS sys_audit_updated_by 
FROM apps a
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1 
    FROM {{ this }} existing 
    WHERE existing.app_id = a.app_id
    AND existing.app_published_country = a.app_published_country
)
{% endif %}