{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['subscription_id', 'instance_number', 'attempt'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with runs as (
    select
        subscription_id
        ,instance_number
        ,attempt
        ,status
        ,date(next_attempt_date) as next_attempt_date
        ,date(next_instance_date) as next_instance_date
        from {{ source('stg_subscriptions', 'runs_upcoming') }}
)
SELECT
    r.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from runs r