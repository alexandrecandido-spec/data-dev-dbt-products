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
    cast(i.id as bigint) as invoice_id,
    cast(i.store_id as bigint) as store_id,
    cast(i.order_id as bigint) as order_id,
    cast(i.fulfillment_order_id as string) as fulfillment_order_id,
    cast(i.invoice_type as string) as invoice_type,
    cast(i.status as string) as invoice_status,
    cast(i.key as string) as invoice_key,
    cast(i.authorization_protocol as string) as authorization_protocol,  
    cast(i.created_at as timestamp) as invoice_created_at,
    cast(i.authorized_at as timestamp) as invoice_authorized_at,
    cast(i.series as string) as invoice_series,
    cast(i.number as string) as invoice_number,
    cast(i.year_month_code as int) as invoice_year_month_code,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by

FROM {{ source('stg_invoices_br', 'invoice') }} i
LEFT JOIN existing_data e ON cast(i.id as bigint) = e.invoice_id

{% if is_incremental() %}
WHERE COALESCE(i.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}