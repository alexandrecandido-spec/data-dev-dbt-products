{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['metaplan_id'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with metaplans as (  select 
    date(created_at) as created_date
    ,store_id
    ,promotion_id
    ,id as metaplan_id
    ,name as metaplan_name
    ,deleted as is_metaplan_deleted
  from {{ source('stg_subscriptions', 'metaplans') }}
)
SELECT
    m.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from metaplans m
where 
{% if is_incremental() %}
  created_date >= (select coalesce(max(created_date),'1900-01-01') from {{ this }} )
{% endif %}