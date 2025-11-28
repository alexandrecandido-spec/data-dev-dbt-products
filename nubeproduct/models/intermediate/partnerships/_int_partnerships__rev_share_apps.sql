with
merchants as (
  select
    distinct store_id
    ,case when group_name = 'enterprise' then 'Next'
          when group_name in ('plan-a', 'plan-b', 'plan-c') then 'SMB'
          else 'freemium'
      end as store_type
  from {{ ref('company_metrics_merchant_info') }}
  order by 1 desc
),
orders as (
    select 
        date(completed_at) as registered_date
        ,id as order_id
        ,o.store_id
        ,store_type
        ,country
        ,payment
        ,shipping
        ,total
        ,total_in_usd
        ,gateway_method
from {{ ref('company_metrics_paid_orders') }} o
left join merchants m
  on o.store_id = m.store_id
where date(completed_at) >= date('2025-01-01')
),
apps as (
    select
        id as app_id
        ,handle as app_handle
    from {{ ref('moltres__mwp_apps') }}
),
app_orders as (
select
  registered_date
  ,order_id
  ,store_id
  ,store_type
  ,country
  ,payment as app_name
  ,'payments' as app_category
  ,a.app_id as app_id
  ,gateway_method
  ,total as total_gmv_local_currency
  ,total_in_usd as total_gmv_usd
from orders o
inner join apps a
on o.payment = a.app_handle
----
union all
----
select
  registered_date
  ,order_id
  ,store_id
  ,store_type
  ,country
  ,shipping as app_name
  ,'shipping' as app_category
  ,a.app_id as app_id
  ,gateway_method
  ,total as total_gmv_local_currency
  ,total_in_usd as total_gmv_usd
from orders o
inner join apps a
on o.shipping = a.app_handle
),
month_total_gmv as (
  select
    date_trunc('month', registered_date) as registered_month
    ,app_id
    ,country
    ,sum(total_gmv_local_currency) as monthly_total_gmv_lc
  from app_orders
  group by 1,2,3
),
rev_share as (
select 
  cast(app_id as int) as app_id
  ,country
  ,date_format(to_date(start_date, 'MM/dd/yyyy'), 'yyyy-MM-dd') as start_date
  ,date_format(to_date(end_date, 'MM/dd/yyyy'), 'yyyy-MM-dd') as end_date
  ,rev_share_type
  ,rev_share_amount
  ,condition_1
  ,value_1
  ,condition_2
  ,value_2
  ,condition_3
  ,value_3
from {{ source('stg_unity_data_manual', 'ext__partnerships__platform_development__revenue_share_apps') }}
where true
)
select 
  registered_date
  ,order_id
  ,store_id
  ,store_type
  ,a.country
  ,app_name
  ,app_category
  ,a.app_id
  ,total_gmv_local_currency
  ,monthly_total_gmv_lc
  ,gateway_method
  ,case when r.app_id is not null then true else false end as has_rev_share_agreement
  ,r.rev_share_type
  ,r.rev_share_amount
  ,condition_1
  ,value_1
  ,condition_2
  ,value_2
  ,condition_3
  ,value_3
  ,case when r.app_id is not null then
      case
        when r.rev_share_type = 'Percent' 
            and condition_1 = 'gateway_method' 
            and value_1 = gateway_method 
            and condition_2 = store_type
            then true
        when r.rev_share_type = 'Percent' and condition_1 = 'GMV Min' and monthly_total_gmv_lc between value_1 and value_2 then true
        when r.rev_share_type = 'Percent' and condition_1 = 'gateway_method' and value_1 = gateway_method and condition_2 is null then true
        when r.rev_share_type = 'Fixed' and condition_1 = 'gateway_method' and value_1 = gateway_method then true
    end
    end as has_condition_compliance
  ,case when r.app_id is not null then
      case
        when r.rev_share_type = 'Fixed' then r.rev_share_amount
        when r.rev_share_type = 'Percent' then total_gmv_local_currency * (r.rev_share_amount)
        end
      end as rev_share_order_amount
from app_orders a
left join rev_share r
  on a.app_id = r.app_id
  and a.country = r.country
  and a.registered_date between r.start_date and r.end_date
left join month_total_gmv m
  on a.app_id = m.app_id
  and a.country = m.country
  and date_trunc('month',a.registered_date) = m.registered_month
where true
order by 1,2,3