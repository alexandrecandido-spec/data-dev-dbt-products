{{
  config(
    materialized='incremental',
    unique_key='invoice_tax_id',
    on_schema_change='fail',
    tags=['finance', 'daily-10am'],
    column_types={
      'invoice_tax_id': 'string',
      'invoice_id': 'string',
      'tax_code': 'string'
    }
  )
}}

WITH source_data AS (
  SELECT
    CAST(id AS string)              AS invoice_tax_id,
    CAST(invoiceid AS string)       AS invoice_id,
    CAST(taxcode AS string)         AS tax_code,
    amountvalue                     AS amount_value,
    sys_audit_created_on            AS source_sys_audit_created_on,
    sys_audit_created_by            AS source_sys_audit_created_by,
    CAST(date_format(sys_audit_created_on, 'yyyyMMdd') AS int) AS year_month_day_code
  FROM {{ source('stg_billing','invoice_tax') }}
  {% if is_incremental() %}
    -- Sem coluna updatedat; usamos sys_audit_created_on como watermark com margem de 1h
    WHERE sys_audit_created_on >= (
      SELECT COALESCE(MAX(sys_audit_created_on), TIMESTAMP '1900-01-01') - INTERVAL 1 HOUR
      FROM {{ this }}
    )
  {% endif %}
),

existing_data AS (
  {{ get_existing_data(this, ['invoice_tax_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
  s.invoice_tax_id,
  s.invoice_id,
  s.tax_code,
  s.amount_value,
  s.year_month_day_code,
  COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data s
LEFT JOIN existing_data e
  ON s.invoice_tax_id = e.invoice_tax_id