{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['country', 'created_at', 'device'],
    partition_by = 'year_month_day_code',
    on_schema_change = 'fail',
    tags = ['daily-9am'] 
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['country', 'created_at', 'device', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT 
  main_source.country
, main_source.created_at
, main_source.year_month_day_code
, main_source.device
, main_source.stores_source_spark_catalog
, main_source.stores_source_empty
, main_source.stores_total
, COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on
, COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by
, current_timestamp AS sys_audit_updated_on
, 'data-dev-dbt-products' AS sys_audit_updated_by
FROM {{ ref('_int_marketing_store_attribution__agg_completeness') }} main_source
LEFT JOIN existing_data e
                          ON main_source.country = e.country AND main_source.created_at = e.created_at AND main_source.device = e.device
WHERE
    {% if not is_incremental() %}
      main_source.created_at >= DATE '2010-01-01'
    {% endif %}
    {% if is_incremental() %}
      main_source.created_at > (
        SELECT COALESCE(MAX(created_at), DATE '1900-01-01')
        FROM {{ this }}
      )
    {% endif %}