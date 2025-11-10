{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['subs_option_id'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with options as (
    select
      date(created_at) as creation_date
      ,id as subs_option_id
      ,metaplan_id
      ,frequency_type
      ,frequency_param
      ,discount_percentage
      ,deleted as is_subs_option_deleted
    from {{ source('stg_subscriptions', 'subscription_options') }}
)
SELECT
    o.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from options o