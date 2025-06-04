{{ config(
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['click_id'],
    partition_by = 'created_at',
    on_schema_change = 'fail',
    tags = ["marketing", 'daily-9am']
) }}

WITH existing_data AS (
  {{ get_existing_data(this, ['click_id', 'created_at', 'sys_audit_created_on', 'sys_audit_created_by']) }}
),

main_data AS (
  SELECT
    main_source.*,
    CASE WHEN main_source.click_order = main_source.click_qty THEN 1 ELSE 0 END AS trials_last_click, 
    CASE WHEN main_source.click_order = 1 THEN 1 ELSE 0 END  AS trials_first_click,
    1/cast(main_source.click_qty AS FLOAT) AS trials_mean_click
  FROM {{ ref('_int_marketing_attribution__get_mkt_source_classification') }} main_source
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
)

SELECT 
  m.*,
  COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM main_data m
LEFT JOIN existing_data e
  ON m.click_id = e.click_id