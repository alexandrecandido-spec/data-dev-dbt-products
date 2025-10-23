{{ config(
  materialized='incremental',
    unique_key=[
    'store_id','completed_at',
    'gateway','payment','shipping','storefront',
    'currency','country_currency','platform_type'
  ],
  incremental_strategy='merge',
  on_schema_change='fail',
  partition_by='year_month_day_code',
  tags=['daily-9am']
) }}
 
 with base as (
 SELECT 
  gmv.*  
  , current_timestamp as sys_audit_created_on
  , 'data-dev-dbt-products' as sys_audit_created_by
  , current_timestamp as sys_audit_updated_on
  , 'data-dev-dbt-products' as sys_audit_updated_by
  FROM {{ref ('_int_marketing__daily_gmv_by_store')}} gmv ) 
  
  select * 
  from base
   {% if is_incremental() %} 
    WHERE base.year_month_day_code >= 
       (select coalesce(max(t.year_month_day_code), 20000101) from {{ this }} t)
    --AND YEAR_MONTH_DAY_CODE >= 20251001
  {% endif %}                                        