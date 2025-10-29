{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['unique_id'],
    partition_by = 'registered_month',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

{% set months_lookback = var('months_lookback', 1) %}

with 
store_app_dates as (
    select *
    from {{ ref('_int_platform_store_app_dates') }}
),
orders as (
    SELECT
        date(date_trunc('month', completed_at)) as registered_month
        ,store_id
        ,count(distinct id) as total_orders
        ,sum(total) as total_gmv_local_currency
        ,sum(total_in_usd) as total_gmv_usd
    from {{ ref('company_metrics_paid_orders') }}
    where 
    {% if not is_incremental() %}
    true
    {% endif %}
    {% if is_incremental() %}
    completed_at >= dateadd(month, -{{ months_lookback }}, date_trunc('month', current_date))
    {% endif %}
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
    where 
    {% if not is_incremental() %}
        true
    {% endif %}
    {% if is_incremental() %}
        registered_date >= dateadd(month, -{{ months_lookback }}, date_trunc('month', current_date))
    {% endif %}
    group by 1,2,3,4,5
),
segments as (
    SELECT
        date_trunc('month',datemonth) as registered_month
        ,store_id
        ,segment
    from {{ ref('company_metrics_gmv_and_segments') }}
    where 
    {% if not is_incremental() %}
        true
    {% endif %}
    {% if is_incremental() %}
        datemonth >= dateadd(month, -{{ months_lookback }}, date_trunc('month', current_date))
    {% endif %}
),
aux as (
select distinct
   s.*
   ,case when churned_at is null then 1 else 0 end as is_current_active_store
   ,case when ao.total_orders > 0 and first_payment is null then 1 else 0 end as has_orders
   --,case when (churned_at IS NULL OR churned_at >= s.registered_month) AND creation_date <= last_day(s.registered_month) then 1 else 0 end as is_active_store_in_month
   ,case when s.registered_month = date_trunc('month', creation_date) then 1 else 0 end as is_new_store
   ,case when s.registered_month = date_trunc('month', churned_at) then 1 else 0 end as is_churned_store
   ,sg.segment
   ,o.total_orders
   ,o.total_gmv_local_currency
   ,o.total_gmv_usd
   ,ao.total_orders as app_total_orders
   ,ao.total_gmv_local_currency as app_gmv_lc
   ,ao.total_gmv_usd as app_gmv_usd
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
where true
and s.registered_month >= date_trunc('month', current_date) - interval '12' month
and ((ao.total_orders > 0 and first_payment is null) 
or (s.first_payment is not null and s.churned_at is null))
{% if is_incremental() %}
    and s.registered_month >= dateadd(month, -{{ months_lookback }}, date_trunc('month', current_date))
{% endif %}
),
dedup as (
    select *,
        row_number() over (
            partition by registered_month, store_id, coalesce(app_id,999999)
            order by sys_audit_updated_on desc nulls last
        ) as rn
    from aux
)
SELECT
    concat(a.registered_month, '_', a.store_id, '_', coalesce(a.app_id,999999)) as unique_id
    ,a.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from dedup a
    where rn = 1