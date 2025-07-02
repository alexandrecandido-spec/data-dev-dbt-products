{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['store_id'],
        on_schema_change='fail',
        tags=["marketing","daily-9am"]
    )
}}

with marketing as (
    select *
    from {{ ref('marketing_attribution_model') }}
    where year_month_day_code >= 20200101
),
qualified_orders as (
    select *
    from {{ ref('_int__first_seller_7_or_more_sales_90d') }}
)

select
    ma.store_id,
    date(min(fs.completed_at)) as first_seller_at,
    current_timestamp AS sys_audit_created_on,
    'data-dev-dbt-products' AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
from marketing ma
left join qualified_orders fs
    on ma.store_id = fs.store_id
WHERE
    {% if not is_incremental() %}
      sys_audit_updated_on >= DATE '2010-01-01'
    {% endif %}
    {% if is_incremental() %}
     sys_audit_updated_on > (
        SELECT COALESCE(MAX(sys_audit_updated_on), DATE '1900-01-01')
        FROM {{ this }}
      )
    {% endif %}
group by ma.store_id