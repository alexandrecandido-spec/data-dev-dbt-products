with 
dates as (
    SELECT distinct 
        date(date_id) as registered_date
    FROM {{ ref('dim_calendar') }} 
    where true
    and date_id between date_trunc('month', current_date) - interval '4' month and current_date
),
apps as (
    SELECT
        app_id
        ,app_name
        ,app_category
        ,app_creation_date
        ,app_published_date
        ,app_deleted_date
        ,app_published_country
        ,is_app_published
        ,a.partner_id
        ,p.partner_name
    from {{ ref('product__ecosystem__apps__scd') }} a
    left join {{ref('product__ecosystem__tech_partner__scd')}} p
        on a.partner_id = p.partner_id
),
app_dates as (
    select 
        date(d.registered_date) as registered_date
        ,a.*
        ,case when registered_date = app_creation_date then true else false end as is_new_app
         ,case when registered_date = app_published_date then true else false end as is_new_published_app
         ,case when registered_date = app_deleted_date then true else false end as is_churned_app
         ,case when registered_date between app_creation_date and coalesce('2100-01-01', app_deleted_date) then true else false end as is_active_app
         ,case when registered_date between app_published_date and coalesce('2100-01-01', app_deleted_date) then true else false end as is_public_active_app
    from apps a
    cross join dates d
),
stores as (
    select distinct
        s.id as store_id
        ,s.domain as merchant_name
        ,s.country as store_country
        ,s.plan
        ,g.grupo
        ,g.namev2 as plan_name
        ,s.current_segment
        ,date(s.created_at) as creation_date
        ,date(first_payment) as first_payment
        ,date(churned_at) as churned_at
        ,monthly_fee
    from {{ source('int_moltres', 'mwp_store_info') }} s
    left join `hive_metastore`.`ecommerce`.`mwp_store_settings` ss
        on ss.store_id = s.id
    left join {{ ref('operations_grouping_plans') }} g
        on s.plan = g.plan
    where s.state <> 4
    and first_payment is not null
    and (churned_at is null or date_trunc('month',churned_at) >= date_trunc('month', current_date) - interval '12' month)
    and monthly_fee > 0
),
installs as (
    SELECT
        i.store_id
        ,s.store_country
        ,s.plan
        ,s.grupo
        ,s.current_segment
        ,s.plan_name
        ,i.app_id
        ,a.app_name
        ,a.app_category
        ,a.app_creation_date
        ,a.app_published_date
        ,a.app_deleted_date
        ,a.is_app_published
        ,min(app_install_date) as app_install_date
        ,max(app_uninstall_date) as app_uninstall_date
    from {{ ref('product_platform_mwp_apps_stores') }} I
    left join apps a
        on I.app_id = a.app_id
    left join stores s
        on I.store_id = s.store_id
    where app_name not in ('sellbot', 'compra-rpida-pro')
    group by 1,2,3,4,5,6,7,8,9,10,11,12,13
)
SELECT
    a.registered_date
   ,a.app_id
   ,partner_id
   ,partner_name
   ,A.app_name
   ,a.app_published_country as app_country
   ,store_country
   ,a.app_category as category
   ,a.app_creation_date as creation_date
   ,a.app_deleted_date as deleted_date
   ,a.app_published_date
   ,a.is_app_published
   ,is_new_app
   ,is_new_published_app
   ,is_churned_app
   ,is_active_app
   ,is_public_active_app
   ,i.grupo
   ,i.plan_name
   ,i.current_segment
   ,count(distinct 
            case when  i.app_install_date = a.registered_date 
            then i.store_id 
            end) as daily_installs
   ,count(distinct 
      case when i.app_uninstall_date = a.registered_date 
      then i.store_id 
      end) as daily_uninstalls
   ,count(distinct 
      case when a.registered_date between 
         i.app_install_date
         and coalesce('2100-01-01',i.app_uninstall_date) 
         then i.store_id 
      end) as active_stores
from app_dates a
left join installs i
   on a.app_id = i.app_id
   and a.app_published_country = i.store_country
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20