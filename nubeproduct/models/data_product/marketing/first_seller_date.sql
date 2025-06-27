{{ config(
  unique_key=['store_id'],
  on_schema_change='fail',
  tags=["marketing", "daily-4_30am"]
) }}

with marketing as (
    select *
    from {{ ref('marketing_attribution_model') }}
    where year_month_day_code >= 20250101
),

qualified_orders as (
    select *
    from {{ ref('_int__first_seller_7_or_more_sales_90d') }}
)

select
    ma.store_id,
    date(min(fs.completed_at)) as first_seller_at
from marketing ma
left join qualified_orders fs
    on ma.store_id = fs.store_id
group by ma.store_id
