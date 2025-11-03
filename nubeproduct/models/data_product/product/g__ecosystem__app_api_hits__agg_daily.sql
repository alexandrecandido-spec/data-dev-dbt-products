{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'unique_id',
    partition_by = 'registered_date',
    on_schema_change = 'fail',
    tags = ['daily-8am']
) }}

with api_hits as (
    select 
        registered_date
        ,app_id
        ,store_id
        ,total_api_hits
    from {{ ref('_int_product_ecosystem_api_hits') }}
)
select
    concat(cast(registered_date as string), '_'
            , cast(app_id as string), '_'
            , cast(coalesce(store_id,'no_store') as string)
        ) as unique_id
    ,a.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from api_hits a
{% if is_incremental() %}
where registered_date >= (select coalesce(max(registered_date),'1900-01-01') from {{ this }} )
{% endif %}