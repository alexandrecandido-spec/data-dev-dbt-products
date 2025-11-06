{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = 'unique_id',
    partition_by = 'registered_month',
    on_schema_change = 'fail',
    tags = ['daily-8am'],
    pre_hook = [
        """
        {% if is_incremental() %}
            DELETE FROM {{ this }}
            WHERE registered_month = date_trunc('month', current_date());
        {% endif %}
        """
    ]
) }}

with api_hits as (
    select 
        date_trunc('month', registered_date) as registered_month
        ,app_id
        ,store_id
        ,sum(total_api_hits) as total_api_hits
    from {{ ref('_int_product_ecosystem_api_hits') }}
    group by 1,2,3
)
select
    concat(cast(registered_month as string), '_'
            , cast(app_id as string), '_'
            , cast(coalesce(store_id,'no_store') as string)
        ) as unique_id
    ,a.*
    ,current_timestamp as sys_audit_created_on
    ,'data-dev-dbt-products' as sys_audit_created_by
    ,current_timestamp as sys_audit_updated_on
    ,'data-dev-dbt-products' as sys_audit_updated_by
from api_hits a
where
{% if not is_incremental() %}
 true
{% endif %}
{% if is_incremental() %}
 registered_month >= date_trunc('month', current_date())
{% endif %}