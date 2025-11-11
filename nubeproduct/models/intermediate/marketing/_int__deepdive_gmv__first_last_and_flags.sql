with months as (
  -- universo (store_id, reported_month) ya normalizado al fin de mes
  select
    store_id,
    mes as reported_month
  from {{ ref('_int__deepdive_gmv__monthly_base_from_daily') }}
  group by 1,2
),
milestones as (
  select
    store_id,
    cast(first_sale as date) as first_sale_date_all_time,
    last_day(cast(first_sale as date)) as first_sale_month_all_time,
    cast(last_sale  as date) as last_sale_date,
    last_day(cast(last_sale  as date)) as last_sale_month,
    cast(sys_audit_updated_on as timestamp) as milestones_audit_updated_on
  from {{ ref('s__lifecycle__store_sales_milestones__ref') }}
)

select
  m.store_id,
  m.reported_month,
  ms.first_sale_date_all_time,
  ms.first_sale_month_all_time,
  ms.last_sale_date,
  ms.last_sale_month,
  case when m.reported_month = ms.first_sale_month_all_time then 1 else 0 end as is_first_sale_month,
  case when m.reported_month = ms.last_sale_month          then 1 else 0 end as is_last_sale_month,
  ms.milestones_audit_updated_on
from months m
left join milestones ms using (store_id)