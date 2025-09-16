{{
  config(
    materialized='incremental',
    unique_key='invoice_id',
    on_schema_change='fail',
    tags=['finance', 'daily-7am']
  )
}}

WITH source_data AS (
    SELECT
        id AS invoice_id,
        -- storeid AS store_id, -- Column not available in source
        associatedinvoiceid AS associated_invoice_id,
        documenttype AS document_type,
        inv.number AS invoice_number,
        amountvalue AS amount_value,
        CAST(issuedat AS DATE) AS issued_at,
        sys_audit_created_on AS source_sys_audit_created_on,
        sys_audit_created_by AS source_sys_audit_created_by,
        updatedat AS updated_at,
        CAST(date_format(issuedat, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM
        {{ source('stg_billing', 'invoice') }} as inv
    WHERE deletedat IS NULL
        AND issuedat IS NOT NULL
        AND inv.number is not null
    {% if is_incremental() %}
        AND updatedat >= (SELECT COALESCE(MAX(updated_at), '1900-01-01') - INTERVAL '1 hour' FROM {{ this }})
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
FROM
    source_data s
LEFT JOIN
    existing_data e ON s.invoice_id = e.invoice_id