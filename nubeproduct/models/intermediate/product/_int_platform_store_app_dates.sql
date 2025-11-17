with 
stores as (
    select
        s.id as store_id
        ,domain as merchant_name
        ,country
        ,mail
        ,phone
        ,type as store_vertical
        ,monthly_fee
        ,date(created_at) as creation_date
        ,date(first_payment) as first_payment
        ,date(churned_at) as churned_at
    from {{ source('int_stg_moltres', 'mwp_store_info') }} s
    left join {{ source('int_stg_moltres', 'mwp_store_settings') }} ss
    on s.id = ss.store_id
    where true
    and state <> 4
    and first_payment is not null
    and (churned_at is null or date_trunc('month',churned_at) >= date_add(month, -12, date_Trunc('month',current_date)))
),
store_dates as (
    select 
        date(d.registered_month) as registered_month
        ,p.*
        ,case when d.registered_month between date_trunc('month', creation_date) and churned_at
               or churned_at is null then true else false end as is_active_store
    from stores p
    cross join {{ ref('_int_pd_github_dates') }} d
),
apps as (
    SELECT distinct
        app_id
        ,app_name
        ,app_category
        ,app_creation_date
        ,app_published_date
        ,app_deleted_date
        ,is_app_published
    from {{ ref('product__ecosystem__apps__scd') }}
),
installs as (
    SELECT
        store_id
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
    where app_name not in ('sellbot', 'compra-rpida-pro')
    group by 1,2,3,4,5,6,7,8
),
scripts as (
    SELECT distinct
        store_id
        ,app_id
        ,date(created_date) as created_date
        ,date(deleted_date) as deleted_date
    from {{ ref('product__ecosystem__mwp_scripts__scd') }}
),
shipping_carriers as (
    SELECT distinct
        store_id
        ,app_id
        ,status
        ,date(creation_date) as created_date
        ,date(deletion_date) as deleted_date
    from {{ ref('product__ecosystem__mwp_shipping_carriers__scd') }}
),
partner_managers as (
    select distinct
        country
        ,partner_id
        ,partner_manager
        ,app_id
        ,app_manager
    from {{ source('int_stg_unity_data_manual', 'ext__partnerships__platform_development__app_managers') }}
)
SELECT distinct
        s.*
        ,a.app_id
        ,app_name
        ,app_category
        ,app_manager
        ,is_app_published
        ,app_creation_date
        ,app_published_date
        ,app_deleted_date
        ,app_install_date
        ,app_uninstall_date
        ,case when a.app_id is null then 1 else 0 end as has_no_apps
        ,case when s.registered_month between date_trunc('month', app_install_date) and coalesce('2100-01-01', app_uninstall_date) then 1 else 0 end as is_app_active
        ,case when s.registered_month = date_trunc('month', app_install_date) then 1 else 0 end as is_new_app_install
        ,case when s.registered_month = date_trunc('month', app_uninstall_date) then 1 else 0 end as is_app_churn
        ,sc.created_date as script_creation_date
        ,sc.deleted_date as script_deletion_date
        ,case when s.registered_month = date_trunc('month', sc.created_date) then 1 else 0 end as is_new_script
        ,case when s.registered_month = date_trunc('month', sc.deleted_date) then 1 else 0 end as is_churn_script
        ,case when s.registered_month between date_trunc('month', sc.created_date) and coalesce('2100-01-01',sc.deleted_date) then 1 else 0 end as is_script_active
        ,sh.created_date as shipping_carrier_creation_date
        ,sh.deleted_date as shipping_carrier_deletion_date
        ,sh.status as shipping_carrier_status
        ,case when s.registered_month = date_trunc('month', sh.created_date) then 1 else 0 end as is_new_shipping_carrier_install
        ,case when s.registered_month = date_trunc('month', sh.deleted_date) then 1 else 0 end as is_shipping_carrier_churn
        ,case when sh.status = 1 and s.registered_month between date_trunc('month', sh.created_date) and coalesce('2100-01-01',sh.deleted_date) then 1 else 0 end as is_shipping_carrier_active
from store_dates s
left join installs a
    on s.store_id = a.store_id
left join scripts sc
    on s.store_id = sc.store_id
    and a.app_id = sc.app_id
left join shipping_carriers sh
    on s.store_id = sh.store_id
    and a.app_id = sh.app_id
left join partner_managers pm
    on s.country = pm.country
    and a.app_id = pm.app_id
where is_active_store