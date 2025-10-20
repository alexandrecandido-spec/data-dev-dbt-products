{{ config(
  materialized='incremental',
  unique_key=['store_id','completed_at'],
  incremental_strategy='merge',
  on_schema_change='fail',
  partition_by='year_month_day_code',
  tags=['daily-9am']
) }}
 SELECT 
  gmv.*  
  , current_timestamp as sys_audit_created_on
  , 'data-dev-dbt-products' as sys_audit_created_by
  , current_timestamp as sys_audit_updated_on
  , 'data-dev-dbt-products' as sys_audit_updated_by
  FROM {{ref ('_int_marketing__daily_gmv_by_store')}} gmv
  where 1=1
  {% if is_incremental() %}
    AND gmv.completed_at >= 
      (SELECT COALESCE(MAX(sys_audit_updated_on), '2000-01-01') FROM {{ this }}) 
  {% endif %}
                                            