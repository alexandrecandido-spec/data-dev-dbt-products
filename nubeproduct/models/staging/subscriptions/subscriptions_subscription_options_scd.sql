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
      ,cast(id as string) as subs_option_id
      ,cast(metaplan_id as string) as metaplan_id
      ,cast(frequency_type as string) as frequency_type
      ,cast(frequency_param as integer) as frequency_param
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
{% if is_incremental() %}
  WHERE
  creation_date >= (select coalesce(max(creation_date),'1900-01-01') from {{ this }} )
  or (is_subs_option_deleted = true and subs_option_id in (select subs_option_id from {{ this }} where is_subs_option_deleted = false))
{% endif %}