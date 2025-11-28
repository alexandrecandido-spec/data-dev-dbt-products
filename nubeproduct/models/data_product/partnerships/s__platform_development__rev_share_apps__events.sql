{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['registered_date','order_id','store_id', 'app_id'],
    partition_by = 'registered_date',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

with
rev_share_orders as (
select distinct
  registered_date
  ,order_id
  ,gateway_method
  ,store_id
  ,store_type
  ,country
  ,app_id
  ,app_name
  ,app_category
  ,total_gmv_local_currency
  ,monthly_total_gmv_lc
  ,has_rev_share_agreement
  ,rev_share_type
  ,rev_share_amount
  ,condition_1
  ,value_1
  ,condition_2
  ,value_2
  ,condition_3
  ,value_3
  ,has_condition_compliance
  ,rev_share_order_amount
from {{ ref('_int_partnerships__rev_share_apps') }}
where true
and has_condition_compliance
and  has_rev_share_agreement
)
select distinct
    r.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from rev_share_orders r
{% if is_incremental() %}
    where registered_date >= (select coalesce(max(registered_date),'1900-01-01') from {{ this }})
{% endif %}