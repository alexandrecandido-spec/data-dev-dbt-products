{{
    config(
        tags = ['product', 'daily-8am'],
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='request_id',
        on_schema_change='fail'
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['request_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    cast(ir.id as bigint) as request_id,
    cast(ir.store_id as bigint) as store_id,
    cast(ir.order_id as bigint) as order_id,
    cast(ir.fulfillment_order_id as string) as fulfillment_order_id,
    cast(ir.invoice_type as string) as invoice_type,
    cast(ir.status as string) as request_status,
    cast(ir.created_at as timestamp) as request_created_at,
    cast(ir.enriched_at as timestamp) as request_enriched_at,
    cast(ir.sent_at as timestamp) as request_sent_at,
    cast(ir.finished_at as timestamp) as request_finished_at,
    cast(ir.reason as string) as rejected_request_reason,
    cast(ir.year_month_code as int) as request_year_month_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_invoices_br', 'invoice_request') }} ir
LEFT JOIN existing_data e ON cast(ir.id as bigint) = e.request_id

{% if is_incremental() %}
WHERE COALESCE(ir.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}