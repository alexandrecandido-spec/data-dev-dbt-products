{{
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['request_id'],
        on_schema_change = 'fail',
        tags = ['daily-8am']
    )
}}

WITH existing_data AS (
    {{ get_existing_data(this, ['request_id', 'sys_audit_created_on', 'sys_audit_created_by']) }}
)

SELECT
    iar.request_id,
    iar.store_id,
    iar.plan_group,
    iar.store_state,
    iar.current_segment,
    iar.country,
    iar.order_id,
    iar.request_created_date,
    iar.invoice_type,
    iar.request_status,
    iar.is_prd_environment,
    iar.request_error_group,
    iar.request_error_code,
    iar.invoice_status,
    iar.invoice_created_date,
    iar.invoice_authorized_date,
    iar.invoice_cancelled_date,
    COALESCE(e.sys_audit_created_on, current_timestamp) AS sys_audit_created_on,
    COALESCE(e.sys_audit_created_by, 'data-dev-dbt-products') AS sys_audit_created_by,
    current_timestamp AS sys_audit_updated_on,
    'data-dev-dbt-products' AS sys_audit_updated_by


FROM {{ ref('_int__product__invoicing__invoices_and_requests') }} iar
LEFT JOIN existing_data e
    ON iar.request_id = e.request_id

{% if is_incremental() %}
WHERE COALESCE(iar.sys_audit_updated_on, current_timestamp) >= (
    SELECT COALESCE(MAX(sys_audit_updated_on), '1900-01-01') FROM {{ this }}
)
{% endif %}