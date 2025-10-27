{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='invoice_id',
        on_schema_change='fail'
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['invoice_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    cast(ii.id as bigint) as invoice_id,
    cast(ii.invoice_request_id as bigint) as request_id,
    cast(ii.cancelled_at as timestamp) as invoice_cancelled_at,
    cast(ii.cancellation_event_id as integer) as cancellation_event_id,
    cast(ii.last_correction_event_id as integer) as last_correction_event_id,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_invoices_br', 'internal_invoice') }} ii
LEFT JOIN existing_data e ON cast(ii.id as bigint) = e.invoice_id

{% if is_incremental() %}
WHERE COALESCE(ii.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}