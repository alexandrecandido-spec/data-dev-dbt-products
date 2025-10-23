with 
stores as (
    select
        s.store_id
        ,domain as merchant_name
        ,country_code as country
        ,mail
        ,phone
        ,vertical_name as store_vertical
        ,group_name
        ,date(created_at) as creation_date
        ,date(first_payment) as first_payment
from {{ ref('company_metrics_merchant_info') }} s
left join {{ source('bronze_risk_ecommerce', 'mwp_store_settings') }} ss
  on s.store_id = ss.store_id
),
store_dates as (
    select 
        d.registered_month
        ,p.*
    from stores p
    cross join {{ ref('_int_pd_github_dates') }} d
),
orders as (
    SELECT
        date(date_trunc('month', completed_at)) as registered_month
        ,store_id
        ,count(distinct id) as total_orders
        ,sum(total) as total_gmv_local_currency
        ,sum(total_in_usd) as total_gmv_usd
    from {{ ref('company_metrics_paid_orders') }}
    group by 1,2
),
app_orders as (
    select
        date_trunc('month',registered_date) as registered_month
        ,store_id
        ,app_id
        ,app_name
        ,app_category
        ,sum(total_orders) as total_orders
        ,sum(total_gmv_local_currency) as total_gmv_local_currency
        ,sum(total_gmv_usd) as total_gmv_usd
    from {{ ref('g__platform__app_orders__agg_daily') }}
    group by 1,2,3,4,5
),
apps as (
    SELECT
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
    group by 1,2,3,4,5,6,7,8
),
segments as (
    SELECT
    date_trunc('month',datemonth) as registered_month
    ,store_id
    ,segment
from {{ ref('company_metrics_gmv_and_segments') }}
),
scripts as (
    SELECT
        store_id
        ,app_id
        ,date(created_date) as created_date
        ,date(deleted_date) as deleted_date
    from {{ ref('product__ecosystem__mwp_scripts__scd') }}
),
shipping_carriers as (
    SELECT
        store_id
        ,app_id
        ,status
        ,date(creation_date) as created_date
        ,date(deletion_date) as deleted_date
    from {{ ref('product__ecosystem__mwp_shipping_carriers__scd') }}
)
SELECT distinct
        s.*
        ,a.app_id
        ,app_name
        ,app_category
        ,is_app_published
        ,app_install_date
        ,app_uninstall_date
        ,case when a.app_id is null then 1 else 0 end as has_no_apps
        ,case when s.registered_month between date_trunc('month', app_install_date) and coalesce('2100-01-01', app_uninstall_date) then 1 else 0 end as is_app_active
        ,case when s.registered_month = date_trunc('month', app_install_date) then 1 else 0 end as is_new_app_install
        ,case when s.registered_month = date_trunc('month', app_uninstall_date) then 1 else 0 end as is_app_churn
        ,sc.created_date as script_creation_date
        ,sc.deleted_date as script_deletion_date
        ,case when s.registered_month = date_trunc('month', sc.created_date) then 1 else 0 end as is_new_scrtip
        ,case when s.registered_month = date_trunc('month', sc.deleted_date) then 1 else 0 end as is_churn_scrtip
        ,case when s.registered_month between date_trunc('month', sc.created_date) and coalesce('2100-01-01',sc.deleted_date) then 1 else 0 end as is_script_active
        ,sh.created_date as shipping_carrier_creation_date
        ,sh.deleted_date as shipping_carrier_deletion_date
        ,sh.status as shipping_carrier_status
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