{{
  config(
    materialized='incremental',
    unique_key='charge_id',
    on_schema_change='fail',
    tags=['finance', 'daily-7am']
  )
}}

WITH source_data AS (
    SELECT
        id AS charge_id,
        storeId AS store_id,
        conceptId AS concept_id,
        invoiceId AS invoice_id,
        amountValue AS amount_value,
        CAST(fromDate AS DATE) AS from_date,
        CAST(toDate AS DATE) AS to_date,
        externalReference AS external_reference,
        CAST(deletedAt AS TIMESTAMP) AS deleted_at,
        sys_audit_created_on AS source_sys_audit_created_on,
        sys_audit_created_by AS source_sys_audit_created_by,
        updatedat AS updated_at,
        CAST(date_format(fromDate, 'yyyyMMdd') AS INT) AS year_month_day_code
    FROM
        {{ source('stg_billing', 'charge') }}
    WHERE deletedat IS NULL 

    {% if is_incremental() %}
    -- Adicionamos um intervalo de 1 hora para segurança contra atrasos na atualização dos dados
        AND updatedat >= (SELECT COALESCE(MAX(updated_at), '1900-01-01') - INTERVAL '1 hour' FROM {{ this }})
    {% endif %}

),

existing_data AS (
    -- Macro para buscar dados existentes e preservar o histórico de criação
    {{ get_existing_data(this, ['charge_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    s.charge_id,
    s.store_id,
    s.concept_id,
    s.invoice_id,
    s.amount_value,
    s.from_date,
    s.to_date,
    s.external_reference,
    s.deleted_at,
    s.year_month_day_code,
    s.updated_at,
    -- Lógica para manter a data de criação original e atualizar as demais colunas de auditoria
    COALESCE(e.sys_audit_created_on, s.source_sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, s.source_sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by
FROM
    source_data s
LEFT JOIN
    existing_data e ON s.charge_id = e.charge_id