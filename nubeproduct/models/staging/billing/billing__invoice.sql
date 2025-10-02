{{
  config(
    materialized='incremental',
    unique_key='invoice_id',
    on_schema_change='fail',
    tags=['finance', 'daily-10am'],
    column_types={
      'invoice_id': 'string',
      'associated_invoice_id': 'string',
      'document_type': 'string',
      'invoice_number': 'string'
    }
  )
}}

WITH source_data AS (
  SELECT
    CAST(id AS string)                  AS invoice_id,
    CAST(associatedinvoiceid AS string) AS associated_invoice_id,
    CAST(documenttype AS string)        AS document_type,
    CAST(inv.number AS string)          AS invoice_number,
    amountvalue                         AS amount_value,
    CAST(issuedat AS date)              AS issued_at,
    sys_audit_created_on                AS source_sys_audit_created_on,
    sys_audit_created_by                AS source_sys_audit_created_by,
    updatedat                           AS updated_at,
    CAST(date_format(issuedat, 'yyyyMMdd') AS int) AS year_month_day_code
  FROM {{ source('stg_billing', 'invoice') }} AS inv
  WHERE deletedat IS NULL
    AND issuedat IS NOT NULL
    AND inv.number IS NOT NULL
  {% if is_incremental() %}
    AND updatedat >= (
      SELECT COALESCE(MAX(updated_at), TIMESTAMP '1900-01-01') - INTERVAL 1 HOUR
      FROM {{ this }}
    )
  {% endif %}
),

existing_data AS (
  {{ get_existing_data(this, ['invoice_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
  s.invoice_id,
  s.associated_invoice_id,
  s.document_type,
  s.invoice_number,
  s.amount_value,
  s.issued_at,
  s.year_month_day_code,
  s.updated_at,
  COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
  COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
  current_timestamp AS sys_audit_updated_on,
  'data-dev-dbt-products' AS sys_audit_updated_by
FROM source_data s
LEFT JOIN existing_data e
  ON s.invoice_id = e.invoice_id
