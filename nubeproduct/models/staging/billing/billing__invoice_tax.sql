{{
  config(
    materialized='incremental',
    unique_key='invoice_tax_id',
    on_schema_change='fail',
    tags=['finance', 'daily-7am']
  )
}}

WITH source_data AS (
    SELECT
        id AS invoice_tax_id,
        invoiceid AS invoice_id,
        taxcode AS tax_code,
        amountvalue AS amount_value,
        sys_audit_created_on AS source_sys_audit_created_on,
        sys_audit_created_by AS source_sys_audit_created_by,
        -- updatedat column not available in this source table
        CAST(date_format(sys_audit_created_on, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM
        {{ source('stg_billing', 'invoice_tax') }}

    -- No updatedat column available for incremental logic
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
    -- s.updated_at, -- Column not available
    COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    source_data s
LEFT JOIN
    existing_data e ON s.invoice_tax_id = e.invoice_tax_id