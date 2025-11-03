{{ config(
    materialized='incremental',
    incremental_strategy='replace_where',
    unique_key=['unique_id'],
    replace_where="registered_month = date_trunc('month', current_date)",
    on_schema_change='fail',
    tags=['daily-8am']
) }}

{% set months_lookback = var('months_lookback', 1) %}

with 
store_app_dates as (
    select *
    from {{ ref('_int_platform_store_app_dates') }}
),
orders as (
    select
        date(date_trunc('month', completed_at)) as registered_month,
        store_id,
        count(distinct id) as total_orders,
        sum(total) as total_gmv_local_currency,
        sum(total_in_usd) as total_gmv_usd
    from {{ ref('company_metrics_paid_orders') }}
    where 
    {% if is_incremental() %}
        completed_at >= date_trunc('month', current_date)
    {% else %}
        true
    {% endif %}
    group by 1,2
),
app_orders as (
    select
        date_trunc('month', registered_date) as registered_month,
        store_id,
        app_id,
        app_name,
        app_category,
        sum(total_orders) as total_orders,
        sum(total_gmv_local_currency) as total_gmv_local_currency,
        sum(total_gmv_usd) as total_gmv_usd
    from {{ ref('g__platform__app_orders__agg_daily') }}
    where 
    {% if is_incremental() %}
        registered_date >= date_trunc('month', current_date)
    {% else %}
        true
    {% endif %}
    group by 1,2,3,4,5
),
segments as (
    select
        date_trunc('month', datemonth) as registered_month,
        store_id,
        segment
    from {{ ref('company_metrics_gmv_and_segments') }}
    where
    {% if is_incremental() %}
        datemonth >= date_trunc('month', current_date)
    {% else %}
        true
    {% endif %}
),
api_hits as (
    select
        registered_month
        ,app_id
        ,store_id
        ,total_api_hits
    from {{ ref('g__ecosystem__app_api_hits__agg_monthly') }}
    where
    {% if is_incremental() %}
        registered_month >= date_trunc('month', current_date)
    {% else %}
        true
    {% endif %}
)
aux as (
    select distinct
        concat(s.registered_month, '_', s.store_id, '_', coalesce(s.app_id, 999999)) as unique_id,
        s.*,
        case when churned_at is null then 1 else 0 end as is_current_active_store,
        case when ao.total_orders > 0 and first_payment is null then 1 else 0 end as has_orders,
        case when s.registered_month = date_trunc('month', creation_date) then 1 else 0 end as is_new_store,
        case when s.registered_month = date_trunc('month', churned_at) then 1 else 0 end as is_churned_store,
        sg.segment,
        o.total_orders,
        o.total_gmv_local_currency,
        o.total_gmv_usd,
        ao.total_orders as app_total_orders,
        ao.total_gmv_local_currency as app_gmv_lc,
        ao.total_gmv_usd as app_gmv_usd
        ,ah.total_api_hits as app_api_hits
        ,case 
            when app_category = 'tools'
             and is_app_active
             and is_script_active
             and total_api_hits > 0
            then true
         when app_category = 'shipping'
          and is_app_active
          and is_shipping_carrier_active
          and total_api_hits > 0
       then true
         when app_category not in ('tools', 'shipping')
          and is_app_active
          and total_api_hits > 0
       then true
   else false
   end as is_monthly_mau
    from store_app_dates s
    left join orders o
        on s.store_id = o.store_id
        and s.registered_month = o.registered_month
    left join segments sg
        on s.store_id = sg.store_id
        and sg.registered_month = s.registered_month
    left join app_orders ao
        on s.store_id = ao.store_id
        and s.registered_month = ao.registered_month
        and s.app_id = ao.app_id
    left join api_hits ah
        on s.app_id = ah.app_id
        and s.store_id = ah.store_id
        and s.registered_month = ah.registered_month
    where 
        s.registered_month >= dateadd(month, -12, date_trunc('month', current_date))
        and (
            (ao.total_orders > 0 and first_payment is null) 
            or (s.first_payment is not null and s.churned_at is null)
        )
    {% if is_incremental() %}
        and s.registered_month = date_trunc('month', current_date)
    {% endif %}
)
select
    a.*,
    current_timestamp() as sys_audit_created_on,
    'data-dev-dbt-products' as sys_audit_created_by,
    current_timestamp() as sys_audit_updated_on,
    'data-dev-dbt-products' as sys_audit_updated_by
from aux a
