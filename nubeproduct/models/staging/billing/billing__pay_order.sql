{{
  config(
    materialized='incremental',
    unique_key='pay_order_id',
    on_schema_change='fail',
    tags=['finance', 'daily-10am'],
    column_types={
      'pay_order_id': 'string',
      'status': 'string'
    }
  )
}}

WITH source_data AS (
  SELECT
    CAST(id AS string)               AS pay_order_id,
    CAST(status AS string)           AS status,
    sys_audit_created_on             AS source_sys_audit_created_on,
    sys_audit_created_by             AS source_sys_audit_created_by,
    updatedat                        AS updated_at,
    CAST(date_format(sys_audit_created_on, 'yyyyMMdd') AS int) AS year_month_day_code
  FROM {{ source('stg_billing', 'pay_order') }}
  {% if is_incremental() %}
    WHERE updatedat >= (
      SELECT COALESCE(MAX(updated_at), TIMESTAMP '1900-01-01') - INTERVAL 1 HOUR
      FROM {{ this }}
    )
  {% endif %}
),

existing_data AS (
  {{ get_existing_data(this, ['pay_order_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
  s.pay_order_id,
  s.status,
  s.year_month_day_code,
  s.updated_at,
  COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data s
LEFT JOIN existing_data e
  ON s.pay_order_id = e.pay_order_id
