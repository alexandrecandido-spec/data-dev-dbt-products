{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'unique_partner_country_code',
    partition_by = 'registered_month',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

with 
partner_dates as (
    select
        *
    from {{ ref('_int_platform_tech_partners_dates') }}
),
apps as (
   select
        app_id
        ,partner_id
        ,app_name
        ,app_category
        ,app_creation_date
        ,app_published_date
        ,app_deleted_date
        ,month_creation_date
        ,is_app_published as is_app_published
        ,LISTAGG(app_published_country , ', ') within group (order by app_published_country) as app_published_countries
   from {{ ref('ecosystem__apps') }}
   where app_deleted_date is null
   group by 1,2,3,4,5,6,7,8,9
),
partner_app_countries as (
   select
        partner_id
        ,max(app_published_countries) as app_published_countries
   from apps
   group by 1
),
total_installs as(
   SELECT
      month_install_date
      ,partner_id
      ,app_id
      ,total_installs
      ,total_installs_active
   from {{ ref('_int_platform_tech_partner_installs') }}
),
/*
referrals as (
   SELECT
      *
   from {{ ref('_int_platform_tech_partners_referrals') }}
),
*/
partners as (
select 
   concat(p.registered_month, '_', p.partner_id, '_', p.country_code) as unique_partner_country_code
   ,p.registered_month
   ,p.partner_id
   ,p.partner_name
   ,partner_type
   ,country_code
   ,email
   ,phone_number
   ,website
   ,description
   ,partner_creation_date
   ,is_partner_active
   ,is_new_partner
   --,published_app_countries
   ,count(distinct ai.app_id) as total_apps
   ,count(distinct case when ai.app_published_date is not null then ai.app_id end) as total_published_apps
   ,count(distinct case when ai.app_published_date is null then ai.app_id end) as total_private_apps
   ,sum(total_installs) as total_installs
   ,sum(total_installs_active) as total_installs_active
   --,sum(total_referred_stores) as total_referred_stores
   --,sum(total_referred_payment_stores) as total_referred_payment_stores
from partner_dates p
left join apps ai
   on p.partner_id = ai.partner_id
   and p.registered_month between ai.month_creation_date and current_date
left join total_installs a
   on p.partner_id = a.partner_id
   and p.registered_month = a.month_install_date
/*
left join referrals r
   on p.partner_id = r.referred_partner_id
   and p.registered_month = r.month_creation_date
*/
left join partner_app_countries pac
   on p.partner_id = pac.partner_id
group by 1,2,3,4,5,6,7,8,9,10,11,12,13
having total_apps > 0
)
select 
   p.*
   ,current_timestamp as sys_admin_created_at
   ,'data-dev-dbt-products' as sys_admin_creatd_by
   ,current_timestamp as sys_audit_updated_at
   ,'data-dev-dbt-products' as sys_admin_updated_by
FROM partners p
{% if is_incremental() %}
    WHERE NOT EXISTS (
    SELECT 1 
    FROM {{ this }} existing 
    WHERE existing.partner_id = p.partner_id 
    AND existing.country_code = p.country_code
    and existing.registered_month = p.registered_month
   )
{% endif %}