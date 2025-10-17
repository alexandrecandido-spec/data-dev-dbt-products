{{ config(
  materialized='incremental',
  unique_key=['store_id','completed_at'],
  on_schema_change='fail',
  partition_by='year_month_day_code',
  tags=['daily-9am']
) }}
 SELECT 
  gmv.*  
  , current_timestamp sys_audit_created_on
  , 'data-dev-dbt-products' sys_audit_created_by
  , current_timestamp sys_audit_updated_on
  , 'data-dev-dbt-products' sys_audit_updated_by
  FROM {{ref ('_int_marketing__daily_gmv_by_store')}} gmv
  where gmv.year_month_day_code = '20250930'
  {% if is_incremental() %}
    WHERE gmv.year_month_day_code > (SELECT MAX(year_month_day_code) FROM {{ this }})
  {% endif %}
                                            