{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['unique_store_app_id'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with 
scripts as (
      select distinct
         store_id
         ,app_id
         ,event
         ,"where" as source_event
         ,date(created_at) as created_date
         ,date(deleted_at) as deleted_date
         ,rank() over(partition by app_id,store_id order by id desc) as script_rank
      from {{ source('bronze_risk_ecommerce', 'mwp_scripts') }} s
      where created_at is not null
),
scripts_final as (
select *
from scripts
where script_rank = 1
)
SELECT
    concat(cast(store_id as string), '_', cast(app_id as string)) as unique_store_app_id
    ,s.*
    ,current_timestamp AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
    ,current_timestamp AS sys_audit_updated_on
    ,'data-dev-dbt-products' AS sys_audit_updated_by
from scripts_final s
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1 
    FROM {{ this }} existing 
    WHERE existing.store_id = s.store_id
    AND existing.app_id = s.app_id
)
{% endif %}