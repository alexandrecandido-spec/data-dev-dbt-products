{{
  config(
    materialized='incremental',
    unique_key='charge_id',
    on_schema_change='fail',
    tags=['finance', 'daily-10am'],
    column_types={
      'charge_id': 'string',
      'store_id': 'string',
      'concept_id': 'string',
      'invoice_id': 'string',
      'external_reference': 'string',
      'subscription_id': 'string'
    }
  )
}}

WITH source_data AS (
  SELECT
    CAST(id AS string)              AS charge_id,
    CAST(storeId AS string)         AS store_id,
    CAST(conceptId AS string)       AS concept_id,
    CAST(invoiceId AS string)       AS invoice_id,
    CAST(subscriptionid AS string)  AS subscription_id,
    amountValue                     AS amount_value,
    CAST(fromDate AS date)          AS from_date,
    CAST(toDate AS date)            AS to_date,
    CAST(externalReference AS string) AS external_reference,
    CAST(deletedAt AS timestamp)    AS deleted_at,
    sys_audit_created_on            AS source_sys_audit_created_on,
    sys_audit_created_by            AS source_sys_audit_created_by,
    updatedat                       AS updated_at,
    CAST(date_format(fromDate,'yyyyMMdd') AS int) AS year_month_day_code
  FROM {{ source('stg_billing','charge') }}
  WHERE deletedat IS NULL
  {% if is_incremental() %}
    AND updatedat >= (
      SELECT COALESCE(MAX(updated_at), TIMESTAMP '1900-01-01') - INTERVAL 1 HOUR
      FROM {{ this }}
    )
  {% endif %}),

existing_data AS (
    {{ get_existing_data(this, ['charge_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    s.charge_id,
    s.store_id,
    s.concept_id,
    s.invoice_id,
    s.subscription_id,
    s.amount_value,
    s.from_date,
    s.to_date,
    s.external_reference,
    s.deleted_at,
    s.year_month_day_code,
    s.updated_at,
    COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    source_data s
LEFT JOIN
    existing_data e ON s.charge_id = e.charge_id