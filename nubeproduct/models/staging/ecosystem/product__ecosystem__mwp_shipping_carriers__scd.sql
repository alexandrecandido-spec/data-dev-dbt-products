{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['unique_store_app_id'],
    on_schema_change = 'fail',
    tags = ['product','daily-8am']
) }}

with shipping_carriers as (
      select
         concat('api_', id) as shipping_carrier_id
         ,store_id
         ,app_id
         ,status
         ,date(created_at) as creation_date
         ,date(deleted_at) as deletion_date
         ,rank() over(partition by app_id,store_id order by id desc) as carrier_rank
      from {{ source('bronze_risk_ecommerce', 'mwp_shipping_carriers') }}
),
shipping_carriers_final as (
select
*
from shipping_carriers
where carrier_rank = 1
)
SELECT
    concat(cast(store_id as string), '_', cast(app_id as string)) as unique_store_app_id
    ,s.*
    ,current_timestamp AS sys_audit_created_on
    ,'data-dev-dbt-products' AS sys_audit_created_by
    ,current_timestamp AS sys_audit_updated_on
    ,'data-dev-dbt-products' AS sys_audit_updated_by
from shipping_carriers_final s
{% if is_incremental() %}
WHERE NOT EXISTS (
    SELECT 1 
    FROM {{ this }} existing 
    WHERE existing.store_id = s.store_id
    AND existing.app_id = s.app_id
)
{% endif %}