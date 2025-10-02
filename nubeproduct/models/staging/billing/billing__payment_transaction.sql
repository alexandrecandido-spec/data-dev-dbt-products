{{
  config(
    materialized='incremental',
    unique_key='payment_transaction_id',
    on_schema_change='fail',
    tags=['finance', 'daily-10am'],
    column_types={
      'payment_transaction_id': 'string',
      'pay_order_id': 'string',
      'payment_method_id': 'string',
      'status': 'string',
      'paid_order_id': 'string'
    }
  )
}}

WITH source_data AS (
  SELECT
    CAST(id AS string)               AS payment_transaction_id,
    CAST(payorderid AS string)       AS pay_order_id,
    CAST(paymentmethodid AS string)  AS payment_method_id,
    CAST(status AS string)           AS status,
    CAST(paidat AS timestamp)        AS paid_at,
    sys_audit_created_on             AS source_sys_audit_created_on,
    sys_audit_created_by             AS source_sys_audit_created_by,
    updatedat                        AS updated_at,
    CAST(date_format(paidat, 'yyyyMMdd') AS int) AS year_month_day_code
  FROM {{ source('stg_billing', 'payment_transaction') }}
  {% if is_incremental() %}
    WHERE updatedat >= (
      SELECT COALESCE(MAX(updated_at), TIMESTAMP '1900-01-01') - INTERVAL 1 HOUR
      FROM {{ this }}
    )
  {% endif %}
),

existing_data AS (
  {{ get_existing_data(this, ['payment_transaction_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
  s.payment_transaction_id,
  s.pay_order_id,
  s.pay_order_id AS paid_order_id,
  s.payment_method_id,
  s.status,
  s.paid_at,
  s.year_month_day_code,
  s.updated_at,
  COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data s
LEFT JOIN existing_data e
  ON s.payment_transaction_id = e.payment_transaction_id
