{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['unique_id'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with api_hits as (
    select 
        date as registered_date
        ,app_id as installed_app_id
        ,hits as api_hits
    from {{ source('stg_raw_ecosystem', 'api_calls') }}
)
select 
    concat(cast(registered_date as string), '_'
            ,cast(installed_app_id as string)
        ) as unique_id
    ,a.*
    , current_timestamp as sys_audit_created_on
    , 'data-dev-dbt-products' as sys_audit_created_by
    , current_timestamp as sys_audit_updated_on
    , 'data-dev-dbt-products' as sys_audit_updated_by
from api_hits a
{% if is_incremental() %}
where registered_date >= (select coalesce(max(registered_date),'1900-01-01') from {{ this }} )
{% endif %}