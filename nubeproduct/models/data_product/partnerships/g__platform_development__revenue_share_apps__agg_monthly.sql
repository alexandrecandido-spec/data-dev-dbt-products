{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['unique_id'],
    partition_by = 'registered_month',
    on_schema_change = 'fail',
    tags = ['daily-8am'],
    post_hook = [
        """
        {% if is_incremental() %}
        {% if execute %}
        {% set relation = adapter.get_relation(database=this.database, schema=this.schema, identifier=this.identifier) %}
        {% if relation is not none %}
        DELETE FROM {{ this }}
        WHERE registered_month >= date_trunc('month', current_date());
        {% endif %}
        {% endif %}
        {% endif %}
        """
    ]
) }}

with rev_share_apps as (
select
  date(date_trunc('month', registered_date)) as registered_month
  ,store_id
  ,country
  ,app_id
  ,app_category
  ,app_name
  ,count(distinct order_id) as total_orders
  ,round(sum(total_gmv_local_currency),2) as total_gmv_local_currency
  ,round(max(monthly_total_gmv_lc),2) as max_monthly_gmv_local_currency
  ,round(sum(rev_share_order_amount),2) as total_rev_share
from {{ ref('s__platform_development__rev_share_apps__events') }}
group by 1,2,3,4,5,6
)
select
    concat(cast(registered_month as string), '_'
            , cast(store_id as string), '_'
            , cast(app_id as string)
        ) as unique_id
    ,r.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from rev_share_apps r
{% if is_incremental() %}
    where registered_month >= date_trunc('month', current_date())
{% endif %}